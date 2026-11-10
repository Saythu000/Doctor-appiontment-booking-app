import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/appointment_history_screen.dart';
import 'package:phia_flutter/features/booking/presentation/booking_confirmed_screen.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/review_booking_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_date_time_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_specialist_screen.dart';
import 'package:provider/provider.dart';

import '../booking/booking_viewmodel_failures_test.dart' show FakeHealthRepository, FakeProfileRepository;

final _doctor = PractitionerRoleBooking(
  id: 7,
  active: true,
  practitionerRefId: 70,
  practitionerDisplay: 'Dr. Asha Venkataraman-Krishnamurthy',
  specialties: const ['Cardiology (SPECIALTY)', 'Internal Medicine'],
  availability: [
    PractitionerAvailability(id: 1, availableTimes: [
      AvailableTimeSlot(id: 1, daysOfWeek: const ['mon', 'tue', 'wed', 'thu', 'fri'], allDay: true),
    ]),
  ],
  practitionerDetail: PractitionerDetail(id: 70, fullName: 'Dr. Asha Venkataraman-Krishnamurthy', qualifications: const []),
);

/// Server with one doctor and free times, whose appointment refresh fails
/// (so the "last saved list" banner is shown too).
class FakeBookingRepository extends BookingRepository {
  final bool doctorsFail;
  FakeBookingRepository({this.doctorsFail = false});

  @override
  Future<List<PractitionerRoleBooking>> getActivePractitionerRoles({String? orgId}) async {
    if (doctorsFail) throw Exception('offline');
    return [_doctor];
  }

  @override
  Future<List<BookingSlot>> getAvailableSlots({
    required int practitionerRoleId,
    required String dateString,
    String? orgId,
  }) async {
    String at(int h) => '${dateString}T${h.toString().padLeft(2, '0')}:00:00';
    return [
      for (final (i, h) in [9, 10, 11, 14, 15, 18].indexed)
        BookingSlot(id: i + 1, status: 'free', start: at(h), end: at(h)),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getUserAppointments({required String userId, required String orgId}) async =>
      throw Exception('offline');
}

Future<void> pumpBooking(
  WidgetTester tester,
  Widget screen, {
  Object? extra,
  required double textScale,
  required bool dark,
  bool doctorsFail = false,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final health = FakeHealthRepository();
  final future = DateTime.now().add(const Duration(days: 3)).toIso8601String();
  health.appointments.addAll([
    {
      'id': 'a1',
      'practitioner_name': 'Dr. Asha Venkataraman-Krishnamurthy',
      'practitioner_role': 'Cardiology',
      'practitioner_image': '',
      'start_time': future,
      'is_virtual': 1,
      'status': 'booked',
    },
    {
      'id': 'a2',
      'practitioner_name': 'Dr. Ravi Kumar',
      'practitioner_role': 'Specialist Care', // old placeholder: must not show
      'practitioner_image': 'assets/doctors/doctor_1.png',
      'start_time': '2025-01-01T10:00:00',
      'is_virtual': 0,
      'status': 'fulfilled',
    },
  ]);
  final vm = BookingViewModel(
    bookingRepository: FakeBookingRepository(doctorsFail: doctorsFail),
    healthRepository: health,
    profileRepository: FakeProfileRepository(),
  );

  final router = GoRouter(
    initialLocation: '/',
    initialExtra: extra,
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(path: '/booking/doctors', builder: (_, __) => const SelectSpecialistScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<BookingViewModel>.value(
      value: vm,
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  // Post-frame loads, staggered entrances and the success animation.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Map<String, dynamic> get _timeArgs => {
      'specialist': _doctor,
      'name': 'Dr. Asha Venkataraman-Krishnamurthy',
      'role': 'Cardiology',
      'imageUrl': '',
    };

void main() {
  // Fonts are bundled at build time; tests must not download them.
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final dark in [false, true]) {
    for (final scale in [1.3, 2.0]) {
      final mode = '${dark ? 'dark' : 'light'}, text ${scale}x';

      testWidgets('doctors list fits ($mode)', (tester) async {
        await pumpBooking(tester, const SelectSpecialistScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Book a visit'), findsOneWidget);
        expect(find.text('Dr. Asha Venkataraman-Krishnamurthy'), findsOneWidget);
        expect(find.text('Cardiology'), findsWidgets);
      });

      testWidgets('doctors list error state ($mode)', (tester) async {
        await pumpBooking(tester, const SelectSpecialistScreen(), textScale: scale, dark: dark, doctorsFail: true);
        expect(tester.takeException(), isNull);
        expect(find.text("Couldn't load doctors"), findsOneWidget);
      });

      testWidgets('choose a time fits ($mode)', (tester) async {
        await pumpBooking(tester, const SelectDateTimeScreen(), extra: _timeArgs, textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Choose a time'), findsOneWidget);
        expect(find.text('Pick a time to continue'), findsOneWidget);

        final slot = find.text('09:00 AM');
        await tester.scrollUntilVisible(slot, 150, scrollable: find.byType(Scrollable).first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(slot);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('at 09:00 AM'), findsOneWidget);
      });

      testWidgets('move a visit fits ($mode)', (tester) async {
        await pumpBooking(
          tester,
          const SelectDateTimeScreen(),
          extra: {..._timeArgs, 'reschedule_appointment_id': 'a1'},
          textScale: scale,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Move your visit'), findsOneWidget);
      });

      testWidgets('check your visit fits ($mode)', (tester) async {
        await pumpBooking(
          tester,
          const ReviewBookingScreen(),
          extra: {
            ..._timeArgs,
            'date': 'November 13, 2026',
            'date_raw': DateTime(2026, 11, 13),
            'time': '09:00 AM',
            'slot_id': 1,
            'isVirtual': true,
            'intakeCompleted': true,
            'intakeId': 5,
          },
          textScale: scale,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Confirm appointment'), findsOneWidget);
        expect(find.text('Will be shared with your doctor'), findsOneWidget);
      });

      testWidgets('booking confirmed fits ($mode)', (tester) async {
        await pumpBooking(
          tester,
          const BookingConfirmedScreen(),
          extra: {
            'practitionerName': 'Dr. Asha Venkataraman-Krishnamurthy',
            'practitionerRole': 'Cardiology',
            'date': 'November 13, 2026',
            'time': '09:00 AM',
            'isVirtual': false,
          },
          textScale: scale,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Your visit is booked'), findsOneWidget);
        expect(find.text('Go to Home'), findsOneWidget);
      });

      testWidgets('my appointments fits ($mode)', (tester) async {
        await pumpBooking(tester, const AppointmentHistoryScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('My appointments'), findsOneWidget);
        expect(find.text("Couldn't refresh your appointments. Showing the last saved list."), findsWidgets);
        await tester.scrollUntilVisible(find.text('Cancel'), 150, scrollable: find.byType(Scrollable).at(1));
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.textContaining('Past ('));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Dr. Ravi Kumar'), 150, scrollable: find.byType(Scrollable).at(1));
        expect(find.text('Dr. Ravi Kumar'), findsOneWidget);
        expect(find.text('Specialist Care', skipOffstage: false), findsNothing);
      });
    }
  }
}
