import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../data/repository/auth_repository.dart';
import '../data/repository/health_repository.dart';
import '../data/service/background_sync_service.dart';
import '../data/service/fhir_api_client.dart';
import '../data/service/notification_service.dart';
import '../data/service/secure_storage_service.dart';
import '../domain/model/auth_models.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _refreshToken;
  String? _jwtToken;
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

  /// Refresh an expired JWT transparently using the OAuth 2.0 refresh_token.
  Future<String?> refreshToken() async {
    final generation = _sessionGeneration;
    bool signedOutMeanwhile() => generation != _sessionGeneration;

    // Login is OAuth 2.0 PKCE only, so the refresh token is the one way to
    // renew the session.
    final storedRefreshToken = _refreshToken ?? await healthRepository.getSetting('iam_refresh_token');
    if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
      try {
        final tokenResponse = await authRepository.refreshOAuth2Token(refreshToken: storedRefreshToken);
        if (signedOutMeanwhile()) return null;
        // Re-mint the short-lived Better Auth JWT (patient guide §1 step 2).
        final minted = await authRepository.mintBetterAuthJwt(accessToken: tokenResponse.accessToken);
        if (signedOutMeanwhile()) return null;
        _jwtToken = _pickApiToken(minted: minted, tokens: tokenResponse);
        if (tokenResponse.idToken != null) {
          _idToken = tokenResponse.idToken;
          await healthRepository.saveSetting('iam_id_token', _idToken!);
        }
        if (tokenResponse.refreshToken != null && tokenResponse.refreshToken!.isNotEmpty) {
          _refreshToken = tokenResponse.refreshToken;
          await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
        }
        await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
        FhirApiClient().configure(
          baseUrl: ApiConstants.fhirGqlUrl,
          token: _jwtToken,
          isLiveMode: true,
        );
        return _jwtToken;
      } catch (e) {
        if (kDebugMode) {
          print('[AuthViewModel] OAuth 2.0 refresh token failed: $e');
        }
      }
    }

    return null;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get jwtToken => _jwtToken;
  String? get idToken => _idToken;
  String? get userId => _userId;
  String? get orgId => _orgId;
  User? get user => _user;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// Sign in with OAuth 2.0 + PKCE in a Chrome Custom Tab (system browser),
  /// then fetch user info and configure FhirApiClient.
  ///
  /// The password is typed into the browser, never into this app, and the
  /// app never sees the IAM session cookie (RFC 8252).
  Future<bool> loginWithPKCE() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Perform OAuth 2.0 PKCE Authorization Code flow
      final OAuth2AuthResult authResult = await authRepository.signInWithPKCE();

      // Step 2: The API token is the Better Auth JWT (patient guide §1 step 2),
      // falling back to the OpenID id_token if IAM did not issue one.
      _jwtToken = _pickApiToken(minted: authResult.sessionJwt, tokens: authResult.tokens);
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
        isLiveMode: true,
      );

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

  /// Token sent as `Authorization: Bearer` to every backend: the Better Auth
  /// JWT when IAM issued one, else the id_token, else the access token.
  static String _pickApiToken({String? minted, required OAuth2TokenResponse tokens}) {
    if (isJwtValid(minted)) return minted!;
    if (isJwtValid(tokens.idToken)) return tokens.idToken!;
    return tokens.accessToken;
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
      final storedRefreshToken = await healthRepository.getSetting('iam_refresh_token');
      final storedJwtToken = await healthRepository.getSetting('iam_jwt_token');
      final storedIdToken = await healthRepository.getSetting('iam_id_token');
      if (storedIdToken != null && storedIdToken.isNotEmpty) {
        _idToken = storedIdToken;
      }

      // Case 1: Renew the session with the OAuth 2.0 refresh token
      if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
        try {
          final tokenResponse = await authRepository.refreshOAuth2Token(refreshToken: storedRefreshToken);
          _refreshToken = tokenResponse.refreshToken ?? storedRefreshToken;
          if (tokenResponse.idToken != null && tokenResponse.idToken!.isNotEmpty) {
            _idToken = tokenResponse.idToken;
          }
          if (tokenResponse.refreshToken != null) {
            await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
          }
          if (_idToken != null) {
            await healthRepository.saveSetting('iam_id_token', _idToken!);
          }

          // FHIR, the AI agents and /api/intake/* expect the Better Auth JWT.
          // It is short-lived, so re-mint it (patient guide §1 step 2).
          final minted = await authRepository.mintBetterAuthJwt(accessToken: tokenResponse.accessToken);
          _jwtToken = _pickApiToken(minted: minted, tokens: tokenResponse);
          await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);

          try {
            final user = await authRepository.getUserInfo(accessToken: tokenResponse.accessToken);
            _user = user;
            _userId = user.id;
          } catch (userErr) {
            final savedUserId = await healthRepository.getSetting('iam_user_id');
            final savedUserName = await healthRepository.getSetting('user_name');
            final savedUserEmail = await healthRepository.getSetting('user_email');
            if (savedUserId != null && savedUserId.isNotEmpty) {
              _userId = savedUserId;
              _user = User(
                id: savedUserId,
                email: savedUserEmail ?? '',
                name: savedUserName ?? 'User',
              );
            }
          }

          _orgId = _extractOrgIdFromJwt(_jwtToken ?? tokenResponse.idToken ?? tokenResponse.accessToken);
          if (_orgId == null || _orgId!.isEmpty) {
            final savedOrg = await healthRepository.getSetting('iam_org_id');
            if (savedOrg != null && savedOrg.isNotEmpty) {
              _orgId = savedOrg;
            }
          }
          if (_orgId == null || _orgId!.isEmpty) {
            _orgId = ApiConstants.defaultOrganizationId;
          }

          await _saveCredentials();

          FhirApiClient().configure(
            baseUrl: ApiConstants.fhirGqlUrl,
            token: _jwtToken,
            isLiveMode: true,
          );

          notifyListeners();
          return true;
        } catch (pkceErr) {
          if (kDebugMode) {
            print('[AuthViewModel] PKCE token refresh during auto-login failed: $pkceErr');
          }
          // Only when the server could not be reached (offline) may we keep
          // using a stored JWT, and only while it is unexpired. A server
          // rejection (revoked/expired refresh token) must end the session.
          if (_isNetworkError(pkceErr) && isJwtValid(storedJwtToken)) {
            final savedUserId = await healthRepository.getSetting('iam_user_id');
            final savedUserName = await healthRepository.getSetting('user_name');
            final savedUserEmail = await healthRepository.getSetting('user_email');
            final savedOrg = await healthRepository.getSetting('iam_org_id');
            if (savedUserId != null && savedUserId.isNotEmpty) {
              _jwtToken = storedJwtToken;
              _refreshToken = storedRefreshToken;
              _userId = savedUserId;
              _orgId = (savedOrg != null && savedOrg.isNotEmpty) ? savedOrg : ApiConstants.defaultOrganizationId;
              _user = User(
                id: savedUserId,
                email: savedUserEmail ?? '',
                name: savedUserName ?? 'User',
              );
              FhirApiClient().configure(
                baseUrl: ApiConstants.fhirGqlUrl,
                token: _jwtToken,
                isLiveMode: true,
              );
              notifyListeners();
              return true;
            }
          }
          if (_isNetworkError(pkceErr)) {
            _autoLoginFailedOffline = true;
            return false;
          }
        }
      }

      // Case 2: Fall back to a stored JWT, only while it is still unexpired.
      if (isJwtValid(storedJwtToken)) {
        final savedUserId = await healthRepository.getSetting('iam_user_id');
        final savedUserName = await healthRepository.getSetting('user_name');
        final savedUserEmail = await healthRepository.getSetting('user_email');
        final savedOrg = await healthRepository.getSetting('iam_org_id');
        if (savedUserId != null && savedUserId.isNotEmpty) {
          _jwtToken = storedJwtToken;
          _userId = savedUserId;
          _orgId = (savedOrg != null && savedOrg.isNotEmpty) ? savedOrg : ApiConstants.defaultOrganizationId;
          _user = User(
            id: savedUserId,
            email: savedUserEmail ?? '',
            name: savedUserName ?? 'User',
          );
          FhirApiClient().configure(
            baseUrl: ApiConstants.fhirGqlUrl,
            token: _jwtToken,
            isLiveMode: true,
          );
          notifyListeners();
          return true;
        }
      }

      return false;
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

    try {
      // 1. Clear in-memory session state
      _refreshToken = null;
      _jwtToken = null;
      _idToken = null;
      _userId = null;
      _orgId = null;
      _user = null;
      _errorMessage = null;

      // 2. Point the API client at the live backend with no credentials.
      // (Never switch to the mock backend: it would fake successful syncs.)
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: null,
        isLiveMode: true,
      );

      // 3. Stop the hourly background vitals upload for this user
      await BackgroundSyncService.cancelAll();

      // 4. Wipe stored credentials and per-user data
      await _wipeLocalUserData();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }

    // 5. Best-effort server-side sign-out (local state is already clean)
    try {
      if (refreshTokenToRevoke != null && refreshTokenToRevoke.isNotEmpty) {
        await authRepository
            .revokeToken(token: refreshTokenToRevoke, tokenTypeHint: 'refresh_token')
            .timeout(const Duration(seconds: 5));
      }
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
    await attempt(() => NotificationService.instance.cancelAll());
  }

  Future<void> _saveCredentials() async {
    if (_refreshToken != null) {
      await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
    }
    if (_jwtToken != null) {
      await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
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
