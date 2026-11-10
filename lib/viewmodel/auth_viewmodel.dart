import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants/api_constants.dart';
import '../data/repository/auth_repository.dart';
import '../data/repository/health_repository.dart';
import '../data/service/background_sync_service.dart';
import '../data/service/fhir_api_client.dart';
import '../data/service/secure_storage_service.dart';
import '../domain/model/auth_models.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _sessionToken;
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

  /// Refresh expired JWT token transparently using active session cookie or OAuth 2.0 refresh_token
  Future<String?> refreshToken() async {
    final generation = _sessionGeneration;
    bool signedOutMeanwhile() => generation != _sessionGeneration;

    // 1. Prioritize session cookie refresh (mints authentic Better-Auth Session JWT for FHIR and AI Intake)
    final session = _sessionToken ?? await healthRepository.getSetting('iam_session_token');
    if (session != null && session.isNotEmpty) {
      try {
        final freshJwt = await authRepository.getJwtToken(sessionCookie: session);
        if (signedOutMeanwhile()) return null;
        if (freshJwt.isNotEmpty) {
          _jwtToken = freshJwt;
          await healthRepository.saveSetting('iam_jwt_token', freshJwt);
          FhirApiClient().configure(
            baseUrl: ApiConstants.fhirGqlUrl,
            token: freshJwt,
            isLiveMode: true,
          );
          return freshJwt;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[AuthViewModel] Session cookie token refresh failed: $e');
        }
      }
    }

    // 2. Fallback to OAuth 2.0 refresh_token if session cookie is absent
    final storedRefreshToken = _refreshToken ?? await healthRepository.getSetting('iam_refresh_token');
    if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
      try {
        final tokenResponse = await authRepository.refreshOAuth2Token(refreshToken: storedRefreshToken);
        if (signedOutMeanwhile()) return null;
        if (isJwtValid(tokenResponse.idToken)) {
          _jwtToken = tokenResponse.idToken;
        } else {
          _jwtToken = tokenResponse.accessToken;
        }
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
  String? get sessionToken => _sessionToken;
  String? get refreshTokenValue => _refreshToken;
  String? get jwtToken => _jwtToken;
  String? get idToken => _idToken;
  String? get userId => _userId;
  String? get orgId => _orgId;
  User? get user => _user;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// Initiate OAuth 2.0 PKCE flow in an in-app WebView or secure custom tab,
  /// retrieve tokens, fetch user info, and configure FhirApiClient.
  Future<bool> loginWithPKCE({BuildContext? context}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Perform OAuth 2.0 PKCE Authorization Code flow
      final OAuth2AuthResult authResult;
      if (context != null) {
        authResult = await authRepository.signInWithInAppOAuth(context);
      } else {
        authResult = await authRepository.signInWithPKCE();
      }

      // Step 2: Bind tokens (Session JWT or OpenID id_token for FHIR/AI intake; OAuth 2.0 Access Token as fallback)
      if (isJwtValid(authResult.sessionJwt)) {
        _jwtToken = authResult.sessionJwt;
      } else if (isJwtValid(authResult.tokens.idToken)) {
        _jwtToken = authResult.tokens.idToken;
      } else {
        _jwtToken = authResult.tokens.accessToken;
      }
      _refreshToken = authResult.tokens.refreshToken;
      _idToken = authResult.tokens.idToken;
      _user = authResult.user;
      _userId = authResult.user.id;
      if (authResult.cookies != null) {
        _sessionToken = authResult.cookies;
      }

      // Step 3: Extract organization ID from sessionJwt, id_token, access_token, or listOrganizations
      _orgId = _extractOrgIdFromJwt(authResult.sessionJwt ?? authResult.tokens.idToken ?? authResult.tokens.accessToken);
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
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }


  /// Initiate email sign-in, retrieve session info, fetch JWT token, and configure FhirApiClient.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Sign in with email and get session token
      final token = await authRepository.signIn(email: email, password: password);
      _sessionToken = token;

      // Step 2: Retrieve full session and user details
      var sessionResponse = await authRepository.getSession(sessionCookie: token);
      _user = sessionResponse.user;
      _userId = sessionResponse.user.id;
      _orgId = sessionResponse.session.activeOrganizationId;

      // Resolve null or empty activeOrganizationId by choosing the first available organization
      if (_orgId == null || _orgId!.isEmpty) {
        final orgs = await authRepository.listOrganizations(sessionCookie: token);
        if (orgs.isNotEmpty) {
          final firstOrgId = orgs[0]['id'] as String;
          await authRepository.setActiveOrganization(sessionCookie: token, organizationId: firstOrgId);
          // Re-fetch session to get the populated active organization
          sessionResponse = await authRepository.getSession(sessionCookie: token);
          _orgId = sessionResponse.session.activeOrganizationId;
        }
      }

      // Step 3: Fetch JWT token
      final jwt = await authRepository.getJwtToken(sessionCookie: token);
      _jwtToken = jwt;

      // Ensure activeOrganizationId is populated from JWT claims if missing from session
      if (_orgId == null || _orgId!.isEmpty) {
        final jwtOrg = _extractOrgIdFromJwt(jwt);
        if (jwtOrg != null && jwtOrg.isNotEmpty) {
          _orgId = jwtOrg;
        }
      }

      // Clear previous user cached data if switching accounts
      final previousUserId = await healthRepository.getSetting('iam_user_id');
      if (previousUserId != null && previousUserId.isNotEmpty && previousUserId != _userId) {
        await healthRepository.clearMetrics();
        await healthRepository.clearLocalAppointments();
        await healthRepository.clearProfile();
      }

      // Save credentials locally
      await _saveCredentials();

      // Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: _jwtToken,
        isLiveMode: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Initiate email registration, retrieve session info, fetch JWT token, and configure FhirApiClient.
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Sign up and get session token
      final token = await authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
      _sessionToken = token;

      // Step 2: Retrieve full session and user details
      var sessionResponse = await authRepository.getSession(sessionCookie: token);
      _user = sessionResponse.user;
      _userId = sessionResponse.user.id;
      _orgId = sessionResponse.session.activeOrganizationId;

      // Resolve null or empty activeOrganizationId by choosing the first available organization
      if (_orgId == null || _orgId!.isEmpty) {
        final orgs = await authRepository.listOrganizations(sessionCookie: token);
        if (orgs.isNotEmpty) {
          final firstOrgId = orgs[0]['id'] as String;
          await authRepository.setActiveOrganization(sessionCookie: token, organizationId: firstOrgId);
          // Re-fetch session to get the populated active organization
          sessionResponse = await authRepository.getSession(sessionCookie: token);
          _orgId = sessionResponse.session.activeOrganizationId;
        }
      }

      // Step 3: Fetch JWT token
      final jwt = await authRepository.getJwtToken(sessionCookie: token);
      _jwtToken = jwt;

      if (_orgId == null || _orgId!.isEmpty) {
        final jwtOrg = _extractOrgIdFromJwt(jwt);
        if (jwtOrg != null && jwtOrg.isNotEmpty) {
          _orgId = jwtOrg;
        }
      }

      // Clear previous user cached data if switching accounts
      final previousUserId = await healthRepository.getSetting('iam_user_id');
      if (previousUserId != null && previousUserId.isNotEmpty && previousUserId != _userId) {
        await healthRepository.clearMetrics();
        await healthRepository.clearLocalAppointments();
        await healthRepository.clearProfile();
      }

      // Save credentials locally
      await _saveCredentials();

      // Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: ApiConstants.fhirGqlUrl,
        token: _jwtToken,
        isLiveMode: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Check for saved credentials in the settings table and attempt auto-login/token refresh.
  Future<bool> checkAutoLogin() async {
    try {
      final savedSessionToken = await healthRepository.getSetting('iam_session_token');
      final storedRefreshToken = await healthRepository.getSetting('iam_refresh_token');
      final storedJwtToken = await healthRepository.getSetting('iam_jwt_token');
      final storedIdToken = await healthRepository.getSetting('iam_id_token');
      if (storedIdToken != null && storedIdToken.isNotEmpty) {
        _idToken = storedIdToken;
      }

      // Case 1: User authenticated via session cookie (Direct Better-Auth email/password or In-App OAuth session)
      // This provides the active session and mints the authentic EdDSA Session JWT for FHIR and AI Intake.
      if (savedSessionToken != null && savedSessionToken.isNotEmpty) {
        try {
          var sessionResponse = await authRepository.getSession(sessionCookie: savedSessionToken);
          _sessionToken = savedSessionToken;
          _user = sessionResponse.user;
          _userId = sessionResponse.user.id;
          _orgId = sessionResponse.session.activeOrganizationId;

          // Resolve null or empty activeOrganizationId by choosing the first available organization
          if (_orgId == null || _orgId!.isEmpty) {
            final orgs = await authRepository.listOrganizations(sessionCookie: savedSessionToken);
            if (orgs.isNotEmpty) {
              final firstOrgId = orgs[0]['id'] as String;
              await authRepository.setActiveOrganization(sessionCookie: savedSessionToken, organizationId: firstOrgId);
              sessionResponse = await authRepository.getSession(sessionCookie: savedSessionToken);
              _orgId = sessionResponse.session.activeOrganizationId;
            }
          }

          // Fetch a fresh Better-Auth Session JWT token
          final jwt = await authRepository.getJwtToken(sessionCookie: savedSessionToken);
          _jwtToken = jwt;

          if (_orgId == null || _orgId!.isEmpty) {
            final jwtOrg = _extractOrgIdFromJwt(jwt);
            if (jwtOrg != null && jwtOrg.isNotEmpty) {
              _orgId = jwtOrg;
            }
          }
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
        } catch (sessErr) {
          if (kDebugMode) {
            print('[AuthViewModel] Session verification failed: $sessErr');
          }
        }
      }

      // Case 2: User authenticated via OAuth 2.0 PKCE refresh token
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

          // Crucial: FHIR middleware and AI intake require Better-Auth EdDSA Session JWT.
          // Prioritize valid unexpired JWT: stored JWT -> fresh idToken -> fresh accessToken
          if (isJwtValid(storedJwtToken)) {
            _jwtToken = storedJwtToken;
          } else if (isJwtValid(tokenResponse.idToken)) {
            _jwtToken = tokenResponse.idToken;
          } else {
            _jwtToken = tokenResponse.accessToken;
          }
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
        }
      }

      // Case 3: Fallback to a stored JWT, only while it is still unexpired.
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
    final sessionCookie = _sessionToken;

    try {
      // 1. Clear in-memory session state
      _sessionToken = null;
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
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        await authRepository
            .signOutBetterAuth(sessionCookie: sessionCookie)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Ignore: the session is already gone from this device.
    }

    // 6. Invalidate WebView session cookies so the next login starts fresh
    try {
      await WebViewCookieManager().clearCookies();
    } catch (e) {
      debugPrint('[AuthViewModel] Error clearing WebView cookies: $e');
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
  }

  Future<void> _saveCredentials() async {
    if (_sessionToken != null) {
      await healthRepository.saveSetting('iam_session_token', _sessionToken!);
    }
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
