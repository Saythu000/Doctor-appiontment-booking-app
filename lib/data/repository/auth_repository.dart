import 'package:dio/dio.dart';
import '../../domain/model/auth_models.dart';

class AuthRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://iam.drgodly.com/api/auth',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': 'https://iam.drgodly.com',
      'Referer': 'https://iam.drgodly.com/',
    },
  ));

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
        final token = data['token'] as String?;
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
  Future<List<Map<String, dynamic>>> listOrganizations({required String sessionCookie}) async {
    try {
      final response = await _dio.get(
        '/organization/list',
        options: Options(
          headers: {
            'Cookie': sessionCookie,
          },
        ),
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
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        throw Exception(data['message']);
      }
    }
    throw Exception(e.message ?? 'An unexpected network error occurred.');
  }
}
