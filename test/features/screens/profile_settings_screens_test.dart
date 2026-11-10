import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';
import 'package:phia_flutter/features/profile/presentation/profile_screen.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/edit_profile_page.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/profile_header.dart';
import 'package:phia_flutter/features/settings/presentation/alert_limits_screen.dart';
import 'package:phia_flutter/features/settings/presentation/clinical_units_screen.dart';
import 'package:phia_flutter/features/settings/presentation/general_settings_screen.dart';
import 'package:phia_flutter/features/settings/presentation/reminders_screen.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/widgets/reminder_editor_sheet.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

// In-memory stand-ins: no database, network or timers.
class FakeProfileVM extends ChangeNotifier implements ProfileViewModel {
  @override
  PlainPatient? currentProfile;
  @override
  bool isProfileLoading = false;
  @override
  String? profileImagePath;

  @override
  Future<void> fetchOrInitProfile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeActivityVM extends ChangeNotifier implements ActivityViewModel {
  @override
  double userHeight = 172;
  @override
  double userWeight = 68.5;
  @override
  int userAge = 36;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthVM extends ChangeNotifier implements AuthViewModel {
  @override
  User? get user => User(id: 'u1', email: 'alexandra.longname@example.com', name: 'Alexandra Rivera-Montgomery');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBookingVM extends ChangeNotifier implements BookingViewModel {
  @override
  List<Map<String, dynamic>> appointmentsList = [
    {'id': 'a1'},
    {'id': 'a2'}
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsVM extends ChangeNotifier implements SettingsViewModel {
  @override
  String weightUnit = 'kg';
  @override
  String heightUnit = 'cm';
  @override
  List<Map<String, dynamic>> remindersList = [];
  @override
  Map<String, Map<String, double>> vitalsThresholds = {};

  @override
  bool get usesPounds => weightUnit == 'lbs';
  @override
  bool get usesFeetInches => heightUnit != 'cm';
  @override
  String formatWeight(double kg) => UnitFormat.weight(kg, pounds: usesPounds);
  @override
  String formatHeight(double cm) => UnitFormat.height(cm, feetInches: usesFeetInches);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _patient = PlainPatient(
  id: 4821,
  active: true,
  gender: 'female',
  birthDate: '1990-04-12',
  name: [PlainPatientName(givenName: 'Alexandra', familyName: 'Rivera-Montgomery')],
  telecom: [
    PlainPatientTelecom(system: 'email', value: 'alexandra.longname@example.com'),
    PlainPatientTelecom(system: 'phone', value: '+91 98765 43210'),
  ],
  address: [
    PlainPatientAddress(
      line: ['Flat 12B, Long Avenue Residency, Sector 21'],
      city: 'Bengaluru',
      state: 'Karnataka',
      postalCode: '560001',
      country: 'India',
    ),
  ],
);

final _reminders = <Map<String, dynamic>>[
  {
    'id': '1',
    'title': 'Metformin 500 mg after breakfast',
    'type': 'Medication',
    'time': '08:00',
    'days': 'Daily',
    'is_active': 1
  },
  {
    'id': '2',
    'title': 'Blood pressure',
    'type': 'Vitals Check',
    'time': '19:30',
    'days': 'Mon,Wed,Fri',
    'is_active': 0
  },
];

Future<FakeSettingsVM> pumpSmall(
  WidgetTester tester,
  Widget screen, {
  required double textScale,
  required bool dark,
  PlainPatient? profile,
  bool profileLoading = false,
  List<Map<String, dynamic>> reminders = const [],
  String weightUnit = 'kg',
  String heightUnit = 'cm',
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = FakeSettingsVM()
    ..remindersList = List.of(reminders)
    ..weightUnit = weightUnit
    ..heightUnit = heightUnit;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileViewModel>.value(
          value: FakeProfileVM()
            ..currentProfile = profile
            ..isProfileLoading = profileLoading,
        ),
        ChangeNotifierProvider<ActivityViewModel>.value(value: FakeActivityVM()),
        ChangeNotifierProvider<AuthViewModel>.value(value: FakeAuthVM()),
        ChangeNotifierProvider<BookingViewModel>.value(value: FakeBookingVM()),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  return settings;
}

/// Scrolls the first scrollable to the end so every item is laid out.
Future<void> scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('UnitFormat', () {
    test('converts and formats weight', () {
      expect(UnitFormat.weight(70, pounds: false), '70.0 kg');
      expect(UnitFormat.weight(70, pounds: true), '154.3 lb');
      expect(UnitFormat.weight(0, pounds: true), '--');
      expect(UnitFormat.poundsToKg(UnitFormat.kgToPounds(81.2)), closeTo(81.2, 1e-9));
    });

    test('converts and formats height', () {
      expect(UnitFormat.height(172, feetInches: false), '172 cm');
      expect(UnitFormat.height(172, feetInches: true), '5 ft 8 in');
      expect(UnitFormat.height(0, feetInches: false), '--');
      expect(UnitFormat.cmToFeetInches(UnitFormat.feetInchesToCm(5, 11)), (5, 11));
    });
  });

  group('labels', () {
    test('profile helpers never invent data', () {
      expect(genderLabel(null), 'Not set');
      expect(genderLabel('female'), 'Female');
      expect(birthDateLabel(null), 'Not set');
      expect(birthDateLabel('1990-04-12', today: DateTime(2026, 4, 11)), '12 Apr 1990 (35 years)');
      expect(initialsFor('Asha  Rao'), 'AR');
      expect(initialsFor(''), '');
      expect(describeReminderDays('Daily'), 'Every day');
      expect(describeReminderDays('Mon,Tue,Wed,Thu,Fri'), 'Weekdays');
      expect(describeReminderDays('Mon,Wed'), 'Mon, Wed');
    });
  });

  for (final dark in [false, true]) {
    for (final scale in [1.3, 2.0]) {
      final mode = '${dark ? 'dark' : 'light'}, ${scale}x';

      testWidgets('profile tab fits a small phone ($mode)', (tester) async {
        await pumpSmall(tester, const ProfileScreen(isTab: true),
            textScale: scale, dark: dark, profile: _patient, reminders: _reminders);
        expect(tester.takeException(), isNull);
        expect(find.text('Personal details'), findsOneWidget);
        await scrollToEnd(tester);
        expect(find.text('Sign out'), findsOneWidget);
      });

      testWidgets('profile tab without a profile asks to complete it ($mode)', (tester) async {
        await pumpSmall(tester, const ProfileScreen(isTab: true), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Complete your profile'), findsOneWidget);
        await scrollToEnd(tester);
      });

      testWidgets('edit profile form fits ($mode)', (tester) async {
        await pumpSmall(tester, const EditProfilePage(), textScale: scale, dark: dark, profile: _patient);
        expect(tester.takeException(), isNull);
        expect(find.text('Alexandra'), findsOneWidget);
        await scrollToEnd(tester);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('body measurements fits, metric and imperial ($mode)', (tester) async {
        await pumpSmall(tester, const GeneralSettingsScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('172'), findsOneWidget);
        await scrollToEnd(tester);

        await pumpSmall(tester, const GeneralSettingsScreen(),
            textScale: scale, dark: dark, weightUnit: 'lbs', heightUnit: 'in.');
        expect(tester.takeException(), isNull);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
        expect(find.text('151.0'), findsOneWidget);
        await scrollToEnd(tester);
      });

      testWidgets('units fits ($mode)', (tester) async {
        await pumpSmall(tester, const ClinicalUnitsScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Weight'), findsOneWidget);
        expect(find.textContaining('Temperature'), findsNothing);
        await scrollToEnd(tester);
      });

      testWidgets('reminders list and empty state fit ($mode)', (tester) async {
        await pumpSmall(tester, const RemindersScreen(), textScale: scale, dark: dark, reminders: _reminders);
        expect(tester.takeException(), isNull);
        expect(find.text('Every day'), findsOneWidget);

        await pumpSmall(tester, const RemindersScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('No reminders yet'), findsOneWidget);
      });

      testWidgets('reminder editor fits ($mode)', (tester) async {
        await pumpSmall(tester, const RemindersScreen(), textScale: scale, dark: dark, reminders: _reminders);
        await tester.tap(find.text('Blood pressure'));
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        expect(find.text('Edit reminder'), findsOneWidget);
        expect(find.text('Wed'), findsOneWidget); // "pick days" restored from Mon,Wed,Fri
        await scrollToEnd(tester);
      });

      testWidgets('alert limits fits ($mode)', (tester) async {
        await pumpSmall(tester, const AlertLimitsScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Heart rate', skipOffstage: false), findsOneWidget);
        await scrollToEnd(tester);
        expect(find.text('Save limits'), findsOneWidget);
      });
    }
  }

  testWidgets('alert limits rejects a low limit above the high one', (tester) async {
    await pumpSmall(tester, const AlertLimitsScreen(), textScale: 1, dark: false);
    await tester.enterText(find.widgetWithText(TextFormField, 'Lowest'), '110');
    await tester.enterText(find.widgetWithText(TextFormField, 'Highest'), '100');
    await scrollToEnd(tester);
    await tester.tap(find.text('Save limits'));
    await tester.pump();
    expect(find.text('Lowest heart rate must be below the highest.'), findsOneWidget);
  });

  testWidgets('edit profile requires first and last name and a valid email', (tester) async {
    await pumpSmall(tester, const EditProfilePage(), textScale: 1, dark: false, profile: _patient);
    await tester.enterText(find.widgetWithText(TextFormField, 'First name *'), '');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await scrollToEnd(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Please enter your first name', skipOffstage: false), findsOneWidget);
    expect(find.text('Enter a valid email address', skipOffstage: false), findsOneWidget);
  });
}
