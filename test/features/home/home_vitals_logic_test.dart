import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/features/home/presentation/widgets/doctor_avatar.dart';
import 'package:phia_flutter/features/home/presentation/widgets/next_appointment_card.dart';
import 'package:phia_flutter/features/notifications/presentation/notification_center_sheet.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/domain/vitals_payload.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';

void main() {
  group('findNextAppointment', () {
    final now = DateTime(2026, 11, 11, 10);
    Map<String, dynamic> appt(String id, DateTime start, [String status = 'booked']) =>
        {'id': id, 'start_time': start.toUtc().toIso8601String(), 'status': status};

    test('picks the nearest upcoming visit', () {
      final next = findNextAppointment([
        appt('later', now.add(const Duration(days: 2))),
        appt('soon', now.add(const Duration(hours: 3))),
      ], now: now);
      expect(next?['id'], 'soon');
    });

    test('keeps a visit for 30 minutes after it starts', () {
      expect(findNextAppointment([appt('now', now.subtract(const Duration(minutes: 20)))], now: now)?['id'], 'now');
      expect(findNextAppointment([appt('over', now.subtract(const Duration(minutes: 31)))], now: now), isNull);
    });

    test('skips cancelled, finished and broken rows', () {
      expect(
        findNextAppointment([
          appt('c', now.add(const Duration(hours: 1)), 'cancelled'),
          appt('f', now.add(const Duration(hours: 1)), 'fulfilled'),
          {'id': 'bad', 'start_time': null},
        ], now: now),
        isNull,
      );
    });
  });

  group('BodyUnits', () {
    test('converts weight and height both ways', () {
      expect(BodyUnits.weightFromDisplay(BodyUnits.weightToDisplay(70, 'lbs'), 'lbs'), closeTo(70, 1e-9));
      expect(BodyUnits.heightFromDisplay(BodyUnits.heightToDisplay(175, 'in.'), 'in.'), closeTo(175, 1e-9));
      expect(BodyUnits.formatWeight(70, 'lbs'), '154 lbs');
      expect(BodyUnits.formatWeight(70, 'kg'), '70.0 kg');
      expect(BodyUnits.formatHeight(175, 'in.'), '69 in');
      expect(BodyUnits.formatHeight(0, 'cm'), '--');
    });

    test('BMI is unknown without height or weight, and labelled "Normal" in range', () {
      expect(Bmi.from(weightKg: 0, heightCm: 170), isNull);
      final bmi = Bmi.from(weightKg: 65, heightCm: 170)!;
      expect(bmi.label, 'Normal');
      expect(bmi.tone, StatusTone.success);
    });

    test('time since sync reads naturally', () {
      final now = DateTime(2026, 11, 11, 10);
      expect(VitalsFormat.ago(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(VitalsFormat.ago(now.subtract(const Duration(minutes: 6)), now: now), '6 min ago');
      expect(VitalsFormat.ago(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(VitalsFormat.minutes(95), '1h 35m');
      expect(VitalsFormat.count(0), '--');
    });
  });

  test('remote records count for today only when recorded today', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    expect(ActivityViewModel.isRecordFromToday(VitalsRecord(recordedAt: now.toUtc().toIso8601String())), isTrue);
    expect(ActivityViewModel.isRecordFromToday(VitalsRecord(recordedAt: yesterday.toUtc().toIso8601String())), isFalse);
    expect(ActivityViewModel.isRecordFromToday(VitalsRecord()), isFalse);
  });

  test('doctor avatar uses initials unless the photo is a real web address', () {
    expect(DoctorAvatar.initialsOf('Dr. Asha Rao'), 'AR');
    expect(DoctorAvatar.initialsOf('Meena'), 'M');
    expect(DoctorAvatar.initialsOf(''), 'Dr');
    expect(DoctorAvatar.isRealUrl('https://example.org/a.jpg'), isTrue);
    expect(DoctorAvatar.isRealUrl(''), isFalse);
    expect(DoctorAvatar.isRealUrl('assets/doctors/doctor_1.png'), isFalse);
  });

  test('alert types map to a label, with a neutral default', () {
    expect(AlertKind.of('VITALS_WARNING').label, 'Vitals');
    expect(AlertKind.of('APPOINTMENT_STATUS').label, 'Visit');
    expect(AlertKind.of('SOMETHING_NEW').tone, StatusTone.neutral);
  });
}
