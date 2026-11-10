import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/features/profile/data/profile_repository.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';

/// In-memory stand-in for the sqflite-backed repository.
class FakeHealthRepository implements HealthRepository {
  final Map<String, String> settings = {'iam_user_id': 'user-1', 'iam_org_id': 'org-1'};
  final List<Map<String, dynamic>> appointments = [];
  int clearCalls = 0;
  final List<String> deleted = [];

  @override
  Future<String?> getSetting(String key) async => settings[key];
  @override
  Future<void> saveSetting(String key, String value) async => settings[key] = value;
  @override
  Future<String?> getProfileValue(String key) async => null;
  @override
  Future<void> saveProfileValue(String key, String value) async {}
  @override
  Future<List<Map<String, dynamic>>> getAppointments() async => List.of(appointments);
  @override
  Future<void> saveAppointment(Map<String, dynamic> appt) async => appointments.add(appt);
  @override
  Future<void> deleteAppointment(String id) async {
    deleted.add(id);
    appointments.removeWhere((a) => a['id'] == id);
  }

  @override
  Future<void> clearLocalAppointments() async {
    clearCalls++;
    appointments.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Server that is unreachable for every call.
class OfflineBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> getUserAppointments({
    required String userId,
    required String orgId,
  }) async =>
      throw Exception('offline');

  @override
  Future<void> cancelAppointmentServer(String appointmentId) async =>
      throw Exception('offline');

  @override
  Future<List<PractitionerRoleBooking>> getActivePractitionerRoles({String? orgId}) async => [];

  @override
  Future<List<BookingSlot>> getAvailableSlots({
    required int practitionerRoleId,
    required String dateString,
    String? orgId,
  }) async =>
      throw Exception('offline');
}

class FakeProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

PractitionerRoleBooking _doctor(int id, String name) => PractitionerRoleBooking(
      id: id,
      active: true,
      practitionerDisplay: name,
      specialties: const [],
      availability: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHealthRepository health;
  late BookingViewModel vm;

  setUp(() async {
    health = FakeHealthRepository();
    health.appointments.add({
      'id': 'appt-1',
      'practitioner_name': 'Dr. Asha Rao',
      'start_time': '2020-01-01T10:00:00',
      'status': 'booked',
    });
    vm = BookingViewModel(
      bookingRepository: OfflineBookingRepository(),
      healthRepository: health,
      profileRepository: FakeProfileRepository(),
    );
    // Let the constructor's async loads settle.
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test('offline refresh keeps the cached appointments', () async {
    await vm.fetchAppointments();
    expect(health.clearCalls, 0);
    expect(vm.appointmentsList.map((a) => a['id']), contains('appt-1'));
  });

  test('cancel fails loudly and keeps the appointment when the server rejects it', () async {
    await expectLater(vm.cancelAppointment('appt-1'), throwsA(isA<Exception>()));
    expect(health.deleted, isEmpty);
    expect(health.appointments, isNotEmpty);
  });

  test('reschedule never falls back to a different doctor', () {
    vm.specialists = [_doctor(1, 'Dr. Vikram Shah')];
    final match = vm.findSpecialistForAppointment({'practitioner_name': 'Dr. Asha Rao'});
    expect(match, isNull);
  });

  test('reschedule still matches the same doctor', () {
    vm.specialists = [_doctor(1, 'Dr. Vikram Shah'), _doctor(2, 'Dr. Asha Rao')];
    final match = vm.findSpecialistForAppointment({'practitioner_name': 'Dr. Asha Rao'});
    expect(match?.id, 2);
  });

  test('slot load failure is an error with retry, not "no slots"', () async {
    await vm.fetchBookedSlots(1, DateTime(2030, 1, 1));
    expect(vm.availableSlots, isEmpty);
    expect(vm.slotsError, isNotNull);
    expect(vm.isSlotsLoading, isFalse);
  });
}
