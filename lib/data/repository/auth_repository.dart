import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../core/auth/pkce_helper.dart';
import '../../domain/model/auth_models.dart';
import '../../view/auth/oauth_webview_screen.dart';

class AuthRepository {
  static const String oauthClientId = 'bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT';
  static const String oauthRedirectUri = 'com.drgodly.app://callback';
  static const String oauthCallbackScheme = 'com.drgodly.app';
  static const String oauthScope = 'openid profile email offline_access';
  static const String oauthAuthorizeUrl = 'https://iam.drgodly.com/api/auth/oauth2/authorize';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://iam.drgodly.com/api/auth',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': 'https://iam.drgodly.com',
      'Referer': 'https://iam.drgodly.com/',
    },
  ));

  /// Performs OAuth 2.0 PKCE flow within an In-App WebView.
  /// Captures authorization code + session cookies, and mints the Better-Auth Session JWT for FHIR.
  Future<OAuth2AuthResult> signInWithInAppOAuth(BuildContext context) async {
    final codeVerifier = PkceHelper.generateCodeVerifier();
    final codeChallenge = PkceHelper.generateCodeChallenge(codeVerifier);
    final state = PkceHelper.generateState();

    final authUri = Uri.parse(oauthAuthorizeUrl).replace(
      queryParameters: {
        'client_id': oauthClientId,
        'response_type': 'code',
        'redirect_uri': oauthRedirectUri,
        'scope': oauthScope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    final result = await Navigator.of(context).push<OAuthWebViewResult>(
      MaterialPageRoute(
        builder: (ctx) => OAuthWebViewScreen(
          authorizeUrl: authUri.toString(),
          callbackScheme: oauthCallbackScheme,
        ),
      ),
    );

    if (result == null) {
      throw Exception('Authentication cancelled');
    }

    final callbackUri = Uri.parse(result.callbackUrl);
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'] ?? error;
      throw Exception('OAuth error: $description');
    }

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != state) {
      throw Exception('OAuth security validation failed: state mismatch.');
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('OAuth login failed: No authorization code received.');
    }

    // Exchange authorization code + code_verifier for OAuth tokens
    final tokens = await exchangeCodeForToken(
      code: code,
      codeVerifier: codeVerifier,
    );

    // Fetch user profile from OpenID userinfo endpoint
    final user = await getUserInfo(accessToken: tokens.accessToken);

    // Mint session JWT for FHIR using session cookies if captured
    String? sessionJwt;
    String? effectiveCookie = result.cookies;
    if (effectiveCookie != null && effectiveCookie.isNotEmpty) {
      if (!effectiveCookie.contains('__Secure-better-auth.session_token=') && effectiveCookie.contains('session_token=')) {
        // Normalize name if needed
      }
      try {
        final jwtResp = await _dio.get(
          '/token',
          options: Options(headers: {'Cookie': effectiveCookie}),
        );
        if (jwtResp.statusCode == 200 && jwtResp.data is Map) {
          sessionJwt = jwtResp.data['token'] as String?;
          debugPrint('[AuthRepository] Successfully minted Session JWT from WebView cookie: ${sessionJwt?.substring(0, 15)}...');
        }
      } catch (e) {
        debugPrint('[AuthRepository] Failed to mint Session JWT from cookies: $e');
      }
    }

    return OAuth2AuthResult(
      tokens: tokens,
      user: user,
      sessionJwt: sessionJwt,
      cookies: result.cookies,
    );
  }

  /// Performs OAuth 2.0 Authorization Code Flow with PKCE (RFC 7636).
  /// Opens a secure Chrome Custom Tab / system browser to authenticate,
  /// intercepts the redirect callback com.drgodly.app://callback?code=...,
  /// validates state, exchanges authorization code for tokens, and fetches user profile.
  Future<OAuth2AuthResult> signInWithPKCE() async {
    // 1. Generate high-entropy code_verifier and S256 code_challenge
    final codeVerifier = PkceHelper.generateCodeVerifier();
    final codeChallenge = PkceHelper.generateCodeChallenge(codeVerifier);
    final state = PkceHelper.generateState();

    // 2. Build authorization URL
    final authUri = Uri.parse(oauthAuthorizeUrl).replace(
      queryParameters: {
        'client_id': oauthClientId,
        'response_type': 'code',
        'redirect_uri': oauthRedirectUri,
        'scope': oauthScope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    // 3. Launch secure browser authentication session
    final callbackResult = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: oauthCallbackScheme,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,
        intentFlags: ephemeralIntentFlags,
      ),
    );

    // 4. Parse redirect URI and validate parameters
    final callbackUri = Uri.parse(callbackResult);
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'] ?? error;
      throw Exception('OAuth error: $description');
    }

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != state) {
      throw Exception('OAuth security validation failed: state mismatch.');
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('OAuth login failed: No authorization code received.');
    }

    // 5. Exchange authorization code + code_verifier for OAuth tokens
    final tokens = await exchangeCodeForToken(
      code: code,
      codeVerifier: codeVerifier,
    );

    // 6. Fetch user profile from OpenID userinfo endpoint
    final user = await getUserInfo(accessToken: tokens.accessToken);

    return OAuth2AuthResult(tokens: tokens, user: user);
  }

  /// Exchanges authorization code and code_verifier for access and refresh tokens.
  Future<OAuth2TokenResponse> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final response = await _dio.post(
        '/oauth2/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': oauthClientId,
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': oauthRedirectUri,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        return OAuth2TokenResponse.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Token exchange failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Refreshes OAuth2 access token using refresh_token grant type.
  Future<OAuth2TokenResponse> refreshOAuth2Token({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        '/oauth2/token',
        data: {
          'grant_type': 'refresh_token',
          'client_id': oauthClientId,
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        return OAuth2TokenResponse.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Token refresh failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Revokes an OAuth token (refresh_token or access_token) on DrGodly IAM server (RFC 7009).
  Future<void> revokeToken({
    required String token,
    String tokenTypeHint = 'refresh_token',
  }) async {
    try {
      await _dio.post(
        '/oauth2/revoke',
        data: {
          'client_id': oauthClientId,
          'token': token,
          'token_type_hint': tokenTypeHint,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
    } catch (_) {
      // Best-effort token revocation
    }
  }

  /// Ends session in the system browser / Chrome Custom Tab via OpenID Connect end_session_endpoint.
  /// If the IAM server client has enableEndSession disabled or returns an error, we catch and ignore it
  /// so it does not block user flow or show an error screen to the user.
  Future<void> endSessionInBrowser({String? idToken}) async {
    // Note: iam.drgodly.com currently has enableEndSession disabled for client bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT.
    // When enabled on the server, this cleanly terminates the session in the Custom Tab.
    if (idToken == null || idToken.isEmpty) return;
    try {
      final endSessionUri = Uri.parse('https://iam.drgodly.com/api/auth/oauth2/end-session').replace(
        queryParameters: {
          'id_token_hint': idToken,
          'post_logout_redirect_uri': oauthRedirectUri,
        },
      );
      await FlutterWebAuth2.authenticate(
        url: endSessionUri.toString(),
        callbackUrlScheme: oauthCallbackScheme,
      );
    } catch (_) {
      // Ignore cancellation or dismissal of end-session browser tab
    }
  }

  /// Calls Better-Auth's sign-out endpoint to clear active session on the backend.
  Future<void> signOutBetterAuth({String? sessionCookie}) async {
    try {
      final headers = <String, dynamic>{
        'Origin': 'https://iam.drgodly.com',
        'Referer': 'https://iam.drgodly.com/',
      };
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      await _dio.post(
        '/sign-out',
        data: {},
        options: Options(headers: headers),
      );
    } catch (_) {
      // Best-effort sign out
    }
  }

  /// Retrieves user profile from the standard OIDC userinfo endpoint.
  Future<User> getUserInfo({required String accessToken}) async {
    try {
      final response = await _dio.get(
        '/oauth2/userinfo',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final id = (data['sub'] ?? data['id'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final name = (data['name'] ?? data['given_name'] ?? email.split('@').first).toString();
        final image = data['picture'] as String?;

        return User(
          id: id,
          email: email,
          name: name.isNotEmpty ? name : 'User',
          image: image,
        );
      }
      throw Exception('User info request failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Authenticate with email and password, returning the signed session cookie string.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/sign-in/email',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawToken = data['token'] as String?;
        final cookie = _extractSessionCookie(response.headers, rawToken);
        return cookie;
      }
      throw Exception('Login failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Register a new user and return the signed session cookie string.
  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/sign-up/email',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawToken = data['token'] as String?;
        final cookie = _extractSessionCookie(response.headers, rawToken);
        return cookie;
      }
      throw Exception('Registration failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Get the active session details (user_id and org_id) using the session cookie.
  Future<GetSessionResponse> getSession({required String sessionCookie}) async {
    try {
      final response = await _dio.get(
        '/get-session',
        options: Options(
          headers: {
            'Cookie': sessionCookie,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          return GetSessionResponse.fromJson(data as Map<String, dynamic>);
        }
        throw Exception('Get session returned empty data.');
      }
      throw Exception('Session retrieval failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Generate the final JWT token using the session cookie.
  Future<String> getJwtToken({required String sessionCookie}) async {
    try {
      final response = await _dio.get(
        '/token',
        options: Options(
          headers: {
            'Cookie': sessionCookie,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['token'] ?? data['jwt'] ?? data['access_token']) as String?;
        if (token != null) {
          return token;
        }
        throw Exception('JWT response format invalid: token is missing.');
      }
      throw Exception('JWT token generation failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// List organizations for the user
  Future<List<Map<String, dynamic>>> listOrganizations({
    String? sessionCookie,
    String? bearerToken,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (bearerToken != null && bearerToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $bearerToken';
      } else if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      final response = await _dio.get(
        '/organization/list',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((x) => x as Map<String, dynamic>));
        }
        return [];
      }
      throw Exception('Listing organizations failed with status code: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Set the active organization for the current session
  Future<void> setActiveOrganization({
    required String sessionCookie,
    required String organizationId,
  }) async {
    try {
      final response = await _dio.post(
        '/organization/set-active',
        data: {
          'organizationId': organizationId,
        },
        options: Options(
          headers: {
            'Cookie': sessionCookie,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Set active organization failed with status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Extracts the signed session token cookie from the Set-Cookie headers list.
  String _extractSessionCookie(Headers headers, String? fallbackToken) {
    final setCookies = headers['set-cookie'];
    if (setCookies != null && setCookies.isNotEmpty) {
      for (var cookie in setCookies) {
        if (cookie.contains('better-auth.session_token=')) {
          return cookie.split(';').first.trim();
        }
      }
    }
    // Fallback if cookie was not returned in headers but body had token (e.g. mock server)
    if (fallbackToken != null && fallbackToken.isNotEmpty) {
      return '__Secure-better-auth.session_token=$fallbackToken';
    }
    throw Exception('Session authentication cookie was not returned by the server.');
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    }
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final serverMsg = data['error_description'] ??
            data['message'] ??
            data['detail'] ??
            data['error'];
        if (serverMsg != null && serverMsg.toString().isNotEmpty) {
          throw Exception(serverMsg.toString());
        }
      } else if (data is String && data.isNotEmpty) {
        throw Exception(data);
      }
    }
    throw Exception(e.message ?? 'An unexpected network error occurred.');
  }
}
