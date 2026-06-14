import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class FhirApiClient {
  // Singleton pattern
  static final FhirApiClient _instance = FhirApiClient._internal();
  factory FhirApiClient() => _instance;
  FhirApiClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    ));

    // Offline / Mock mode interceptor to bypass external FHIR server requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_isLiveMode) {
            return handler.next(options);
          }
          if (kDebugMode) {
            print('[FHIR MOCK INTERCEPTOR] Bypassing ${options.method} ${options.path}');
          }
          final path = options.path;
          final method = options.method.toUpperCase();

          // 1. Health checks liveness/readiness
          if (path.contains('/health')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'status': 'ok'},
            ));
          }

          // 2. Specialists list
          if (path.contains('/practitioner-roles') && method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': []}, // Triggers offline mock fallback directory
            ));
          }

          // 3. Appointments list (booked slots)
          if (path.contains('/appointments') && method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': []}, // No occupied slots
            ));
          }

          // 4. Create Encounter
          if (path.contains('/encounters') && method == 'POST') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {'id': 20000 + Random().nextInt(1000)},
            ));
          }

          // 5. Create Appointment
          if (path.contains('/appointments') && method == 'POST') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {'id': 40000 + Random().nextInt(1000)},
            ));
          }

          // 6. Get Profile
          if (path.contains('/patients') && method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': [
                  {
                    'id': 10001,
                    'active': true,
                    'gender': 'male',
                    'birth_date': '1995-05-15',
                    'name': [
                      {
                        'given': ['John'],
                        'family': 'Doe',
                      }
                    ]
                  }
                ]
              },
            ));
          }

          // 7. Create Profile
          if (path.contains('/patients') && method == 'POST' && !path.contains('/names') && !path.contains('/telecom') && !path.contains('/addresses')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 10001,
                'active': true,
              },
            ));
          }

          // 8. Update/Demographics Profile endpoints
          if (path.contains('/patients/') && (method == 'PATCH' || method == 'POST')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 10001,
                'active': true,
                'gender': 'male',
                'birth_date': '1995-05-15',
                'name': [
                  {
                    'given': ['John'],
                    'family': 'Doe',
                  }
                ]
              },
            ));
          }

          // 9. Vitals log submission
          if (path.contains('/vitals') && method == 'POST') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {'status': 'ok'},
            ));
          }

          // 10. Historical Vitals records fetch
          if (path.contains('/vitals') && method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': []},
            ));
          }

          // Fallback resolve
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'status': 'mocked_success'},
          ));
        },
      ),
    );

    // Request Interceptor to dynamically inject active JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (kDebugMode) {
            print('[FHIR API] REQUEST: ${options.method} ${options.uri}');
            if (options.data != null) {
              print('[FHIR API] PAYLOAD: ${jsonEncode(options.data)}');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print('[FHIR API] RESPONSE [${response.statusCode}]: ${response.data}');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) {
            print('[FHIR API] ERROR [${e.response?.statusCode}]: ${e.message}');
            if (e.response?.data != null) {
              print('[FHIR API] ERROR RESPONSE: ${e.response?.data}');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  late final Dio _dio;
  String _baseUrl = 'http://10.0.2.2:8000'; // Default Android Emulator fallback
  String? _token;
  bool _isLiveMode = false;

  Dio get client => _dio;
  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isLiveMode => _isLiveMode;

  /// Configure local server address and active auth JWT Token
  void configure({required String baseUrl, String? token, bool isLiveMode = false}) {
    _baseUrl = baseUrl.trim();
    _dio.options.baseUrl = _baseUrl;
    _token = token;
    _isLiveMode = isLiveMode;
  }

  /// Perform readiness check against FHIR API server
  Future<bool> checkReadiness() async {
    try {
      final response = await _dio.get('/health/ready');
      if (response.statusCode == 200) {
        final data = response.data;
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[FHIR API] Readiness check failed: $e');
      }
      return false;
    }
  }

  /// Perform simple liveness check against FHIR API server (no auth required)
  Future<bool> checkLiveness() async {
    try {
      final response = await _dio.get('/health');
      if (response.statusCode == 200) {
        return response.data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[FHIR API] Liveness check failed: $e');
      }
      return false;
    }
  }
}
