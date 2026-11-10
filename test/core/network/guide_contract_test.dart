import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/features/profile/data/profile_repository.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';

/// Fake FHIR backend: answers every request with [status] and [body], and
/// records each request so tests can check paths and query params.
class ScriptedAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body = const {};
  bool failConnection = false;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failConnection) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ScriptedAdapter server;

  setUp(() {
    final api = FhirApiClient();
    server = ScriptedAdapter();
    api.client.httpClientAdapter = server;
    api.configure(baseUrl: 'https://fhir.test', token: 'jwt', isLiveMode: true);
    api.setTokenRefresher(() async => null);
  });

  group('GET /patients/me (patient guide §3.1)', () {
    test('404 means "needs onboarding" (null)', () async {
      server.status = 404;
      server.body = {'detail': 'not found'};
      expect(await ProfileRepository().getMyProfile(), isNull);
    });

    test('offline is an error, never "no profile" (would create a duplicate)', () async {
      server.failConnection = true;
      await expectLater(ProfileRepository().getMyProfile(), throwsA(isA<DioException>()));
    });

    test('server error is an error, never "no profile"', () async {
      server.status = 500;
      server.body = {'detail': 'boom'};
      await expectLater(ProfileRepository().getMyProfile(), throwsA(isA<DioException>()));
    });

    test('only /patients/me is called (no undocumented fallback)', () async {
      server.status = 404;
      await ProfileRepository().getMyProfile(userId: 'u1', orgId: 'o1');
      expect(server.requests.map((r) => r.path), ['/api/v1/patients/me']);
    });
  });

  test('POST /patients/full failure is not retried via another endpoint (§3.2)', () async {
    server.status = 500;
    await expectLater(
      ProfileRepository().createInitialProfile(userId: 'u1', orgId: 'o1'),
      throwsA(isA<DioException>()),
    );
    expect(server.requests.map((r) => r.path), ['/api/v1/patients/full']);
  });

  test('409 on booking becomes SlotTakenException (§4.3)', () async {
    server.status = 409;
    server.body = {'detail': 'slot not free'};
    await expectLater(
      BookingRepository().bookSlotAtomic(
        practitionerId: 30001,
        slotId: 60001,
        patientId: 10001,
        orgId: 'org_1',
        appointmentTypeDisplay: 'Follow-up',
        practitionerName: 'Dr. Test',
        patientName: 'Test Patient',
      ),
      throwsA(isA<SlotTakenException>()),
    );
  });

  test('empty org-scoped doctor list is not retried without org_id (§2, §4.1)', () async {
    server.body = {'total': 0, 'data': []};
    final roles = await BookingRepository().getActivePractitionerRoles(orgId: 'org_1');
    expect(roles, isEmpty);
    expect(server.requests, hasLength(1));
    expect(server.requests.single.queryParameters['org_id'], 'org_1');
  });

  test('appointments are listed with user_id + org_id only (§5.1)', () async {
    server.body = {'total': 0, 'data': []};
    await BookingRepository().getUserAppointments(userId: 'usr_1', orgId: 'org_1');
    expect(server.requests, hasLength(1));
    final r = server.requests.single;
    expect(r.path, '/api/v1/appointments/');
    expect(r.queryParameters['user_id'], 'usr_1');
    expect(r.queryParameters['org_id'], 'org_1');
  });

  test('slot request failure is an error, not an empty "no slots" list', () async {
    server.status = 500;
    await expectLater(
      BookingRepository().getAvailableSlots(practitionerRoleId: 1, dateString: '2030-01-01', orgId: 'org_1'),
      throwsA(isA<DioException>()),
    );
  });
}
