import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/core/utils/appointment_status.dart';

void main() {
  test('confirmed is never described as cancelled', () {
    final s = AppointmentStatusStyle.of('confirmed');
    expect(s.label, 'CONFIRMED');
    expect(s.description.toLowerCase(), isNot(contains('cancel')));
  });

  test('booked and rescheduled keep their own labels', () {
    expect(AppointmentStatusStyle.of('booked').label, 'BOOKED');
    expect(AppointmentStatusStyle.of('rescheduled').label, 'RESCHEDULED');
  });

  test('a past booked visit is not claimed as completed', () {
    expect(AppointmentStatusStyle.of('booked', isPast: true).label, 'PAST');
    expect(AppointmentStatusStyle.of('fulfilled', isPast: true).label, 'COMPLETED');
    expect(AppointmentStatusStyle.of('cancelled', isPast: true).label, 'CANCELLED');
  });

  test('unknown status falls back to pending', () {
    expect(AppointmentStatusStyle.of(null).label, 'PENDING');
  });
}
