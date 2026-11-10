import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/data/service/fhir_api_client.dart';

/// Fake server: accepts only `Bearer <validToken>`, answers 401 otherwise.
class AuthCheckingAdapter implements HttpClientAdapter {
  AuthCheckingAdapter(this.validToken);
  String validToken;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final ok = options.headers['Authorization'] == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode({'ok': ok}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FhirApiClient api;
  late AuthCheckingAdapter server;

  setUp(() {
    api = FhirApiClient();
    server = AuthCheckingAdapter('fresh');
    api.client.httpClientAdapter = server;
    api.configure(baseUrl: 'https://fhir.test', token: 'expired', isLiveMode: true);
  });

  test('concurrent 401s share a single token refresh, then all succeed', () async {
    var refreshCalls = 0;
    api.setTokenRefresher(() async {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      api.configure(baseUrl: 'https://fhir.test', token: 'fresh', isLiveMode: true);
      return 'fresh';
    });

    final responses = await Future.wait([
      api.client.get('/a'),
      api.client.get('/b'),
      api.client.get('/c'),
    ]);

    expect(refreshCalls, 1);
    expect(responses.map((r) => r.statusCode), everyElement(200));
  });

  test('a token the server still rejects is retried once, not forever', () async {
    server.validToken = 'something-else';
    var refreshCalls = 0;
    api.setTokenRefresher(() async {
      refreshCalls++;
      return 'fresh-but-rejected';
    });

    await expectLater(
      api.client.get('/a'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    // One original request + exactly one retry.
    expect(server.requests, 2);
    expect(refreshCalls, 1);
  });

  test('a failed refresh passes the original 401 through', () async {
    api.setTokenRefresher(() async => null);

    await expectLater(
      api.client.get('/a'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(server.requests, 1);
  });
}
