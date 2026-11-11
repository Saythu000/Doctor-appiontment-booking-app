import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:phia_flutter/core/config/api_constants.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/data/local/secure_storage_service.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';
import 'package:phia_flutter/features/notifications/data/notification_service.dart';
import 'package:phia_flutter/features/vitals/data/background_sync_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _refreshToken;
  String? _jwtToken;

  /// IAM session cookie (`name=value`), used only to mint [_jwtToken].
  String? _sessionCookie;
  String? _idToken;
  String? _userId;
  String? _orgId;
  User? _user;

  /// Incremented on every sign-out. Async work (token refresh) captures it at
  /// start and discards its result if the user signed out in the meantime, so
  /// a late refresh can never bring a signed-out session back.
  int _sessionGeneration = 0;
  bool _isSigningOut = false;

  AuthViewModel({
    required this.authRepository,
    required this.healthRepository,
  }) {
    FhirApiClient().setTokenRefresher(refreshToken);
  }

  /// Helper to check if a token string is a valid, unexpired 3-part JWT
  static bool isJwtValid(String? token) {
    if (token == null || token.isEmpty) return false;
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      var payloadB64 = parts[1];
      while (payloadB64.length % 4 != 0) {
        payloadB64 += '=';
      }
      final payloadJson = utf8.decode(base64Url.decode(payloadB64));
      final Map<String, dynamic> data = jsonDecode(payloadJson);
      final exp = data['exp'];
      // A token without an expiry claim cannot be checked, so it is not trusted.
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      // Add 10-second buffer
      return DateTime.now().isBefore(expiry.subtract(const Duration(seconds: 10)));
    } catch (_) {
      return false;
    }
  }

  /// True when [error] means the server could not be reached at all
  /// (offline, DNS failure, timeout), as opposed to the server rejecting us.
  static bool _isNetworkError(Object error) {
    if (error is! DioException) return false;
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return error.response == null;
      default:
        return false;
    }
  }

  /// Helper to decode activeOrganizationId, org_id, or organizations list from JWT token
  String? _extractOrgIdFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      var payloadB64 = parts[1];
      // Normalize base64 padding
      while (payloadB64.length % 4 != 0) {
        payloadB64 += '=';
      }
      final payloadJson = utf8.decode(base64Url.decode(payloadB64));
      final Map<String, dynamic> data = jsonDecode(payloadJson);
      final org = data['activeOrganizationId'] ?? data['org_id'] ?? data['organization_id'] ?? data['tenant_id'];
      if (org != null && org.toString().isNotEmpty) {
        return org.toString();
      }
      if (data['organizations'] is List && (data['organizations'] as List).isNotEmpty) {
        final first = (data['organizations'] as List).first;
        if (first is Map && first['id'] != null && first['id'].toString().isNotEmpty) {
          return first['id'].toString();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthViewModel] Error decoding JWT claims: $e');
      }
    }
    return null;
  }

  /// Mints a fresh Better Auth JWT with the stored IAM session cookie
  /// (patient guide §1 step 2). The JWT lives only minutes; FhirApiClient
  /// calls this on a 401, and [validJwt] calls it once the JWT has expired.
  ///
  /// Returns null when the IAM session has ended or IAM can't be reached.
  Future<String?> refreshToken() async {
    final generation = _sessionGeneration;
    final cookie = _sessionCookie ?? await healthRepository.getSetting('iam_session_token');
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final jwt = await authRepository.mintBetterAuthJwt(sessionCookie: cookie);
      // A sign-out while this was running wins: never bring the session back.
      if (generation != _sessionGeneration) return null;
      _sessionCookie = cookie;
      _jwtToken = jwt;
      await healthRepository.saveSetting('iam_jwt_token', jwt);
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: jwt,
      );
      return jwt;
    } catch (e, st) {
      debugPrint('[AuthViewModel] Could not mint a fresh JWT: $e\n$st');
      return null;
    }
  }

  /// The current JWT while it is unexpired, otherwise a freshly minted one.
  /// Use this (not [jwtToken]) for calls made outside FhirApiClient, such as
  /// the AI agents and /api/intake/*.
  Future<String?> validJwt() async => isJwtValid(_jwtToken) ? _jwtToken : await refreshToken();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get jwtToken => _jwtToken;
  String? get idToken => _idToken;
  String? get userId => _userId;
  String? get orgId => _orgId;
  User? get user => _user;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// Sign in with OAuth 2.0 + PKCE on the IAM page shown by [openLoginPage]
  /// (the in-app WebView), then fetch user info and configure FhirApiClient.
  ///
  /// The WebView is a stopgap: it is the only way to get the IAM session
  /// cookie that the Better Auth JWT is minted with. See
  /// docs/backend_request_option_b.md for the planned return to Custom Tabs.
  Future<bool> loginWithPKCE({
    required Future<WebLoginResult?> Function(Uri authorizeUrl) openLoginPage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Perform OAuth 2.0 PKCE Authorization Code flow
      final OAuth2AuthResult authResult = await authRepository.signInWithPKCE(openLoginPage: openLoginPage);

      // Step 2: The API token is the Better Auth JWT (patient guide §1 step 2).
      _jwtToken = authResult.sessionJwt;
      _sessionCookie = authResult.sessionCookie;
      _refreshToken = authResult.tokens.refreshToken;
      _idToken = authResult.tokens.idToken;
      _user = authResult.user;
      _userId = authResult.user.id;

      // Step 3: Extract organization ID from sessionJwt, id_token, access_token, or listOrganizations
      _orgId = _extractOrgIdFromJwt(_jwtToken ?? authResult.tokens.idToken ?? authResult.tokens.accessToken);
      if (_orgId == null || _orgId!.isEmpty) {
        try {
          final orgs = await authRepository.listOrganizations(bearerToken: _jwtToken);
          if (orgs.isNotEmpty) {
            _orgId = orgs[0]['id'] as String;
          }
        } catch (e) {
          if (kDebugMode) {
            print('[AuthViewModel] Error fetching organizations for PKCE user: $e');
          }
        }
      }
      if (_orgId == null || _orgId!.isEmpty) {
        _orgId = ApiConstants.defaultOrganizationId;
      }

      // Step 4: Clear previous user cached data if switching accounts
      final previousUserId = await healthRepository.getSetting('iam_user_id');
      if (previousUserId != null && previousUserId.isNotEmpty && previousUserId != _userId) {
        await healthRepository.clearMetrics();
        await healthRepository.clearLocalAppointments();
        await healthRepository.clearProfile();
      }

      // Step 5: Save credentials locally
      await _saveCredentials();

      // Step 6: Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: _jwtToken,
      );
      debugPrint('[AuthViewModel] Logged in successfully: user=$_userId, org=$_orgId, jwtLen=${_jwtToken?.length}');

      // Step 7: Start the hourly background vitals upload for this user
      unawaited(BackgroundSyncService.schedulePeriodicSync());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _friendlyLoginError(e);
      notifyListeners();
      return false;
    }
  }

  /// A user-facing message that never echoes raw exception text (which can
  /// contain request details) back into the UI.
  static String _friendlyLoginError(Object e) {
    final text = e.toString();
    if (text.contains('CANCELED') || text.contains('CANCELLED') || text.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    }
    if (text.contains('state mismatch')) {
      return 'Sign-in could not be verified. Please try again.';
    }
    if ((e is DioException && _isNetworkError(e)) ||
        text.contains('timed out') ||
        text.contains('SocketException') ||
        text.contains('connection error')) {
      return 'Could not reach the sign-in server. Check your connection and try again.';
    }
    return 'Sign-in failed. Please try again.';
  }

  /// Check for saved credentials in the settings table and attempt auto-login/token refresh.
  /// True when the last [checkAutoLogin] returned false only because the
  /// server could not be reached (the user is still signed in on this device).
  /// The splash screen then offers "Try again" instead of the welcome page.
  bool get autoLoginFailedOffline => _autoLoginFailedOffline;
  bool _autoLoginFailedOffline = false;

  Future<bool> checkAutoLogin() async {
    _autoLoginFailedOffline = false;
    try {
      final storedCookie = await healthRepository.getSetting('iam_session_token');
      final storedJwtToken = await healthRepository.getSetting('iam_jwt_token');
      final storedRefreshToken = await healthRepository.getSetting('iam_refresh_token');
      final storedIdToken = await healthRepository.getSetting('iam_id_token');
      final savedUserId = await healthRepository.getSetting('iam_user_id');

      // Sessions from the Custom Tabs build have no IAM session cookie, so
      // they can never get a JWT the backend accepts: sign in again.
      if (storedCookie == null || storedCookie.isEmpty) return false;
      if (savedUserId == null || savedUserId.isEmpty) return false;

      // Renew the short-lived Better Auth JWT with the session cookie.
      String jwt;
      try {
        jwt = await authRepository.mintBetterAuthJwt(sessionCookie: storedCookie);
      } on SessionExpiredException {
        // IAM ended the session (expired, revoked, signed out elsewhere).
        return false;
      } catch (e) {
        if (kDebugMode) {
          print('[AuthViewModel] Auto-login could not mint a JWT: ${e.runtimeType}');
        }
        if (!_isNetworkError(e)) return false;
        // Offline: keep using the stored JWT, but only while it is unexpired.
        if (!isJwtValid(storedJwtToken)) {
          _autoLoginFailedOffline = true;
          return false;
        }
        jwt = storedJwtToken!;
      }

      final savedUserName = await healthRepository.getSetting('user_name');
      final savedUserEmail = await healthRepository.getSetting('user_email');
      final savedOrg = await healthRepository.getSetting('iam_org_id');

      _sessionCookie = storedCookie;
      _jwtToken = jwt;
      if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) _refreshToken = storedRefreshToken;
      if (storedIdToken != null && storedIdToken.isNotEmpty) _idToken = storedIdToken;
      _userId = savedUserId;
      _user = User(
        id: savedUserId,
        email: savedUserEmail ?? '',
        name: (savedUserName != null && savedUserName.isNotEmpty) ? savedUserName : 'User',
      );
      _orgId = _extractOrgIdFromJwt(jwt);
      if (_orgId == null || _orgId!.isEmpty) {
        _orgId = (savedOrg != null && savedOrg.isNotEmpty) ? savedOrg : ApiConstants.defaultOrganizationId;
      }

      await _saveCredentials();
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: _jwtToken,
      );
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthViewModel] Auto-login verification failed: $e');
      }
      return false;
    }
  }

  /// Signs the user out.
  ///
  /// Local data is wiped FIRST, so the device is clean even if the network
  /// calls fail or hang. Server-side revocation is best effort afterwards.
  /// Prefer `signOutAndResetSession(context)`, which also resets the other
  /// view models.
  Future<void> signOut() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    // Invalidate any token refresh that is still in flight (see refreshToken).
    _sessionGeneration++;

    // Keep what the server needs to revoke before clearing memory.
    final refreshTokenToRevoke = _refreshToken;
    String? sessionCookieToEnd = _sessionCookie;

    try {
      sessionCookieToEnd ??= await healthRepository.getSetting('iam_session_token');
    } catch (_) {}

    try {
      // 1. Clear in-memory session state
      _refreshToken = null;
      _jwtToken = null;
      _sessionCookie = null;
      _idToken = null;
      _userId = null;
      _orgId = null;
      _user = null;
      _errorMessage = null;

      // 2. Point the API client at the live backend with no credentials.
      // (Never switch to the mock backend: it would fake successful syncs.)
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
      );

      // 3. Stop the hourly background vitals upload for this user
      await BackgroundSyncService.cancelAll();

      // 4. Wipe stored credentials and per-user data
      await _wipeLocalUserData();

      // 5. Empty the sign-in WebView's cookie store, so the IAM session
      //    cookie is gone from the device too.
      try {
        await WebViewCookieManager().clearCookies().timeout(const Duration(seconds: 3));
      } catch (_) {}
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }

    // 6. Best-effort server-side sign-out (local state is already clean):
    //    end the IAM session and revoke the OAuth refresh token.
    try {
      await Future.wait([
        if (sessionCookieToEnd != null && sessionCookieToEnd.isNotEmpty)
          authRepository.signOutSession(sessionCookie: sessionCookieToEnd),
        if (refreshTokenToRevoke != null && refreshTokenToRevoke.isNotEmpty)
          authRepository.revokeToken(token: refreshTokenToRevoke),
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore: the session is already gone from this device.
    }

  }

  /// Deletes every credential and every piece of user data stored locally.
  /// Each step runs even if an earlier one fails.
  Future<void> _wipeLocalUserData() async {
    Future<void> attempt(Future<void> Function() step) async {
      try {
        await step();
      } catch (e) {
        if (kDebugMode) {
          print('[AuthViewModel] Local wipe step failed: $e');
        }
      }
    }

    // Credentials (secure storage) and account settings
    for (final key in HealthRepository.secureKeys) {
      await attempt(() => healthRepository.saveSetting(key, ''));
    }
    await attempt(() => SecureStorageService().clearAll());
    for (final key in const [
      'iam_user_id',
      'iam_org_id',
      'user_name',
      'user_email',
      // Per-user caches that must not survive into the next session
      'last_intake_record_id',
      'cached_specialists_json',
      'last_vitals_alert_heart_rate',
      'last_vitals_alert_systolic',
      'last_vitals_alert_diastolic',
    ]) {
      await attempt(() => healthRepository.saveSetting(key, ''));
    }

    // Cached profile, health data, appointments, notifications, GPS routes
    await attempt(healthRepository.clearProfile);
    await attempt(healthRepository.clearMetrics);
    await attempt(healthRepository.clearLocalAppointments);
    await attempt(healthRepository.clearAllInAppNotifications);
    await attempt(healthRepository.clearWorkoutRoutes);
    await attempt(healthRepository.clearReminders);
    await attempt(healthRepository.clearVitalsThresholds);

    // Scheduled OS notifications (medication reminders, appointment
    // reminders) belong to this user and must stop firing after sign-out.
    await attempt(NotificationService.instance.cancelAll);
  }

  Future<void> _saveCredentials() async {
    if (_refreshToken != null) {
      await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
    }
    if (_jwtToken != null) {
      await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
    }
    if (_sessionCookie != null) {
      await healthRepository.saveSetting('iam_session_token', _sessionCookie!);
    }
    if (_idToken != null) {
      await healthRepository.saveSetting('iam_id_token', _idToken!);
    }
    if (_userId != null) {
      await healthRepository.saveSetting('iam_user_id', _userId!);
    }
    final effectiveOrgId = (_orgId != null && _orgId!.isNotEmpty) ? _orgId! : ApiConstants.defaultOrganizationId;
    await healthRepository.saveSetting('iam_org_id', effectiveOrgId);
    if (_user != null) {
      await healthRepository.saveSetting('user_name', _user!.name);
      await healthRepository.saveSetting('user_email', _user!.email);
    }
  }
}
