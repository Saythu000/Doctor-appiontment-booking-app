import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:phia_flutter/core/network/native_http_adapter.dart';
import 'package:phia_flutter/features/auth/data/pkce_helper.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';

class AuthRepository {
  static const String oauthClientId = 'bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT';
  static const String oauthRedirectUri = 'com.drgodly.app://callback';
  static const String oauthCallbackScheme = 'com.drgodly.app';
  static const String oauthScope = 'openid profile email offline_access';
  static const String oauthAuthorizeUrl = 'https://iam.drgodly.com/api/auth/oauth2/authorize';

  final Dio _dio;

  AuthRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://iam.drgodly.com/api/auth',
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Origin': 'https://iam.drgodly.com',
                'Referer': 'https://iam.drgodly.com/',
              },
            )) {
    if (!kIsWeb && Platform.isAndroid) {
      _dio.httpClientAdapter = NativeHttpAdapter();
    }
  }

  /// Performs OAuth 2.0 Authorization Code Flow with PKCE (RFC 7636).
  ///
  /// [openLoginPage] shows the IAM sign-in page (the in-app WebView, see
  /// OAuthWebViewScreen) and returns the redirect plus the IAM session
  /// cookie, or null if the user closed it. Then: validate state, exchange
  /// the code for OAuth tokens, fetch the user, and mint the Better Auth JWT
  /// with the session cookie (mobile-patient-api-guide.md §1 step 2).
  Future<OAuth2AuthResult> signInWithPKCE({
    required Future<WebLoginResult?> Function(Uri authorizeUrl) openLoginPage,
  }) async {
    // 1. Generate high-entropy code_verifier and S256 code_challenge
    final codeVerifier = PkceHelper.generateCodeVerifier();
    final codeChallenge = PkceHelper.generateCodeChallenge(codeVerifier);
    final state = PkceHelper.generateState();

    // 2. Build authorization URL. Never add prompt=login: Better Auth then
    //    loops back to the login form after a successful sign-in.
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

    // 3. Show the sign-in page
    final loginResult = await openLoginPage(authUri);
    if (loginResult == null) {
      throw Exception('Sign-in was cancelled.');
    }
    final sessionCookie = loginResult.sessionCookie;

    // 4. Parse redirect URI and validate parameters
    final callbackUri = Uri.parse(loginResult.callbackUrl);
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

    // 7. Exchange the session for the Better Auth JWT (mobile-patient-api-
    //    guide.md §1 step 2). This is the only token the FHIR API, the AI
    //    agents and /api/intake/* accept; it carries `activeOrganizationId`.
    //    Without it nothing works, so sign-in fails instead of continuing
    //    with a token every backend rejects.
    if (sessionCookie == null || sessionCookie.isEmpty) {
      throw Exception('Sign-in could not be completed: no session was created.');
    }
    final betterAuthJwt = await mintBetterAuthJwt(sessionCookie: sessionCookie);

    return OAuth2AuthResult(
      tokens: tokens,
      user: user,
      sessionJwt: betterAuthJwt,
      sessionCookie: sessionCookie,
    );
  }

  /// `GET {BETTER_AUTH_URL}/api/auth/token` (mobile-patient-api-guide.md §1
  /// step 2), authenticated with the IAM session cookie.
  ///
  /// IAM rejects this call with an OAuth access token (verified on a device,
  /// 2026-11-11), so the session cookie is required. The guide documents the
  /// response key as `token`, `jwt` or `access_token`.
  ///
  /// Throws [SessionExpiredException] when IAM rejects the session, and the
  /// original error when the server could not be reached.
  Future<String> mintBetterAuthJwt({required String sessionCookie}) async {
    try {
      final response = await _dio.get(
        '/token',
        options: Options(headers: {'Cookie': sessionCookie}),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        final token = data['token'] ?? data['jwt'] ?? data['access_token'];
        if (token is String && token.isNotEmpty) return token;
      }
      throw Exception('IAM returned no JWT.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) throw SessionExpiredException();
      rethrow;
    }
  }

  /// Ends the IAM session on the server (`POST /api/auth/sign-out`), so the
  /// stored session cookie can no longer mint JWTs. Best effort.
  Future<void> signOutSession({required String sessionCookie}) async {
    try {
      await _dio.post(
        '/sign-out',
        data: const <String, dynamic>{},
        options: Options(headers: {'Cookie': sessionCookie}),
      );
    } catch (_) {
      // The local session is already gone; nothing else to do.
    }
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

  /// List organizations for the user
  Future<List<Map<String, dynamic>>> listOrganizations({
    String? bearerToken,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (bearerToken != null && bearerToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $bearerToken';
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
