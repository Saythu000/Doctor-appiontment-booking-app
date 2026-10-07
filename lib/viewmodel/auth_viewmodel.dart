import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants/api_constants.dart';
import '../data/repository/auth_repository.dart';
import '../data/repository/health_repository.dart';
import '../data/service/fhir_api_client.dart';
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

  AuthViewModel({
    required this.authRepository,
    required this.healthRepository,
  }) {
    FhirApiClient().setTokenRefresher(refreshToken);
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

  /// Refresh expired JWT token transparently using OAuth 2.0 refresh_token or active session cookie
  Future<String?> refreshToken() async {
    // 1. Try OAuth 2.0 refresh_token first
    final storedRefreshToken = _refreshToken ?? await healthRepository.getSetting('iam_refresh_token');
    if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
      try {
        final tokenResponse = await authRepository.refreshOAuth2Token(refreshToken: storedRefreshToken);
        _jwtToken = tokenResponse.accessToken;
        if (tokenResponse.refreshToken != null && tokenResponse.refreshToken!.isNotEmpty) {
          _refreshToken = tokenResponse.refreshToken;
          await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
        }
        await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
        return _jwtToken;
      } catch (e) {
        if (kDebugMode) {
          print('[AuthViewModel] OAuth 2.0 refresh token failed: $e');
        }
      }
    }

    // 2. Fallback to session cookie refresh
    final session = _sessionToken ?? await healthRepository.getSetting('iam_session_token');
    if (session == null || session.isEmpty) return null;
    try {
      final freshJwt = await authRepository.getJwtToken(sessionCookie: session);
      _jwtToken = freshJwt;
      await healthRepository.saveSetting('iam_jwt_token', freshJwt);
      return freshJwt;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthViewModel] Automatic token refresh failed: $e');
      }
      return null;
    }
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

      // Step 2: Bind tokens (prioritizing Better-Auth Session JWT for FHIR middleware)
      _jwtToken = authResult.sessionJwt ?? authResult.tokens.accessToken;
      _refreshToken = authResult.tokens.refreshToken;
      _idToken = authResult.tokens.idToken;
      _user = authResult.user;
      _userId = authResult.user.id;
      if (authResult.cookies != null) {
        _sessionToken = authResult.cookies;
      }

      // Step 3: Extract organization ID from sessionJwt, id_token, access_token, or listOrganizations
      _orgId = (authResult.sessionJwt != null ? _extractOrgIdFromJwt(authResult.sessionJwt!) : null) ??
          _extractOrgIdFromJwt(authResult.tokens.idToken ?? authResult.tokens.accessToken);
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
        baseUrl: 'https://fhirgql.drgodly.com',
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
        baseUrl: 'https://fhirgql.drgodly.com',
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
        baseUrl: 'https://fhirgql.drgodly.com',
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
      final storedRefreshToken = await healthRepository.getSetting('iam_refresh_token');
      final storedJwtToken = await healthRepository.getSetting('iam_jwt_token');
      final storedIdToken = await healthRepository.getSetting('iam_id_token');
      if (storedIdToken != null && storedIdToken.isNotEmpty) {
        _idToken = storedIdToken;
      }

      // Case A: User authenticated via OAuth 2.0 PKCE
      if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
        try {
          final tokenResponse = await authRepository.refreshOAuth2Token(refreshToken: storedRefreshToken);
          _jwtToken = tokenResponse.accessToken;
          _refreshToken = tokenResponse.refreshToken ?? storedRefreshToken;
          if (tokenResponse.idToken != null && tokenResponse.idToken!.isNotEmpty) {
            _idToken = tokenResponse.idToken;
          }
          await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
          if (tokenResponse.refreshToken != null) {
            await healthRepository.saveSetting('iam_refresh_token', _refreshToken!);
          }
          if (_idToken != null) {
            await healthRepository.saveSetting('iam_id_token', _idToken!);
          }

          final user = await authRepository.getUserInfo(accessToken: _jwtToken!);
          _user = user;
          _userId = user.id;
          _orgId = _extractOrgIdFromJwt(tokenResponse.idToken ?? _jwtToken!);
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
            baseUrl: 'https://fhirgql.drgodly.com',
            token: _jwtToken,
            isLiveMode: true,
          );

          notifyListeners();
          return true;
        } catch (pkceErr) {
          if (kDebugMode) {
            print('[AuthViewModel] PKCE token refresh during auto-login failed: $pkceErr');
          }
          // If stored token exists and user info is cached, restore session
          if (storedJwtToken != null && storedJwtToken.isNotEmpty) {
            _jwtToken = storedJwtToken;
            final savedUserId = await healthRepository.getSetting('iam_user_id');
            final savedUserName = await healthRepository.getSetting('user_name');
            final savedUserEmail = await healthRepository.getSetting('user_email');
            final savedOrg = await healthRepository.getSetting('iam_org_id');
            if (savedUserId != null && savedUserId.isNotEmpty) {
              _userId = savedUserId;
              _orgId = (savedOrg != null && savedOrg.isNotEmpty) ? savedOrg : ApiConstants.defaultOrganizationId;
              _user = User(
                id: savedUserId,
                email: savedUserEmail ?? '',
                name: savedUserName ?? 'User',
              );
              FhirApiClient().configure(
                baseUrl: 'https://fhirgql.drgodly.com',
                token: _jwtToken,
                isLiveMode: true,
              );
              notifyListeners();
              return true;
            }
          }
        }
      }

      // Case B: User authenticated via session cookie
      final savedSessionToken = await healthRepository.getSetting('iam_session_token');
      if (savedSessionToken != null && savedSessionToken.isNotEmpty) {
        try {
          // Verify the session is still valid by requesting it again from the server
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
              // Re-fetch session to get the populated active organization
              sessionResponse = await authRepository.getSession(sessionCookie: savedSessionToken);
              _orgId = sessionResponse.session.activeOrganizationId;
            }
          }

          // Fetch a fresh JWT token
          final jwt = await authRepository.getJwtToken(sessionCookie: savedSessionToken);
          _jwtToken = jwt;

          if (_orgId == null || _orgId!.isEmpty) {
            final jwtOrg = _extractOrgIdFromJwt(jwt);
            if (jwtOrg != null && jwtOrg.isNotEmpty) {
              _orgId = jwtOrg;
            }
          }

          // Save the updated credentials (which might have changed organization or JWT expires)
          await _saveCredentials();

          // Configure the FHIR API client for live server mode
          FhirApiClient().configure(
            baseUrl: 'https://fhirgql.drgodly.com',
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

      // Case C: Fallback to stored JWT token if present
      if (storedJwtToken != null && storedJwtToken.isNotEmpty) {
        _jwtToken = storedJwtToken;
        final savedUserId = await healthRepository.getSetting('iam_user_id');
        final savedUserName = await healthRepository.getSetting('user_name');
        final savedUserEmail = await healthRepository.getSetting('user_email');
        final savedOrg = await healthRepository.getSetting('iam_org_id');
        if (savedUserId != null && savedUserId.isNotEmpty) {
          _userId = savedUserId;
          _orgId = (savedOrg != null && savedOrg.isNotEmpty) ? savedOrg : ApiConstants.defaultOrganizationId;
          _user = User(
            id: savedUserId,
            email: savedUserEmail ?? '',
            name: savedUserName ?? 'User',
          );
          FhirApiClient().configure(
            baseUrl: 'https://fhirgql.drgodly.com',
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

  /// Sign out the user, revoke server token, clear local state, end browser session, and reset FhirApiClient to mock mode.
  Future<void> signOut() async {
    // 1. Revoke active token on IAM server (RFC 7009)
    final tokenToRevoke = _refreshToken ?? _sessionToken ?? _jwtToken;
    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      await authRepository.revokeToken(token: tokenToRevoke);
    }

    // 2. Call Better-Auth sign-out API
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      await authRepository.signOutBetterAuth(sessionCookie: _sessionToken);
    }

    // ponytail: Invalidate WebView session cookies so re-login starts completely fresh
    try {
      await WebViewCookieManager().clearCookies();
    } catch (e) {
      debugPrint('[AuthViewModel] Error clearing WebView cookies: $e');
    }

    // 3. Clear in-memory session tokens and state

    _sessionToken = null;
    _refreshToken = null;
    _jwtToken = null;
    _idToken = null;
    _userId = null;
    _orgId = null;
    _user = null;
    _errorMessage = null;

    // Remove stored credentials
    await healthRepository.saveSetting('iam_session_token', '');
    await healthRepository.saveSetting('iam_refresh_token', '');
    await healthRepository.saveSetting('iam_jwt_token', '');
    await healthRepository.saveSetting('iam_id_token', '');
    await healthRepository.saveSetting('iam_user_id', '');
    await healthRepository.saveSetting('iam_org_id', '');
    await healthRepository.saveSetting('user_name', '');
    await healthRepository.saveSetting('user_email', '');

    // Wipe cached demographics/profile settings to prevent local leakage
    await healthRepository.saveProfileValue('given_name', '');
    await healthRepository.saveProfileValue('family_name', '');
    await healthRepository.saveProfileValue('gender', '');
    await healthRepository.saveProfileValue('birth_date', '');
    await healthRepository.saveProfileValue('profile_image_path', '');

    // Clear user cached metrics, profile & appointments from local database
    await healthRepository.clearProfile();
    await healthRepository.clearMetrics();
    await healthRepository.clearLocalAppointments();

    // Reset FhirApiClient to default mock mode (no token, isLiveMode = false)
    FhirApiClient().configure(
      baseUrl: 'http://10.0.2.2:8000',
      token: null,
      isLiveMode: false,
    );

    notifyListeners();
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
