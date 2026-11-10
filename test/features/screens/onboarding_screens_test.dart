import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/onboarding/complete_screen.dart';
import 'package:phia_flutter/features/onboarding/goals_screen.dart';
import 'package:phia_flutter/features/onboarding/profile_setup_screen.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

// In-memory stand-ins: no database, network or timers.
class FakeProfileVM extends ChangeNotifier implements ProfileViewModel {
  @override
  PlainPatient? currentProfile;
  final List<Map<String, String>> saves = [];

  @override
  Future<void> saveProfileDetails({
    required String givenName,
    required String familyName,
    required String gender,
    required String birthDate,
    required String email,
    required String phone,
    required String street,
    required String city,
    required String state,
    required String zip,
    required String country,
  }) async {
    saves.add({'given': givenName, 'gender': gender, 'birthDate': birthDate});
    throw Exception('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeActivityVM extends ChangeNotifier implements ActivityViewModel {
  @override
  double userHeight = 0;
  @override
  double userWeight = 0;
  @override
  int userAge = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthVM extends ChangeNotifier implements AuthViewModel {
  @override
  User? get user => User(id: 'u1', email: 'alex@example.com', name: 'Alex Rivera');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsVM extends ChangeNotifier implements SettingsViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FakeProfileVM> pumpSmall(
  WidgetTester tester,
  Widget screen, {
  required double textScale,
  required bool dark,
  PlainPatient? existing,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final profile = FakeProfileVM()..currentProfile = existing;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileViewModel>.value(value: profile),
        ChangeNotifierProvider<ActivityViewModel>.value(value: FakeActivityVM()),
        ChangeNotifierProvider<AuthViewModel>.value(value: FakeAuthVM()),
        ChangeNotifierProvider<SettingsViewModel>.value(value: FakeSettingsVM()),
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
  await tester.pump(const Duration(seconds: 1));
  return profile;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  const screens = <String, Widget>{
    'profile setup': ProfileSetupScreen(),
    'goals': GoalsScreen(),
    'complete': CompleteScreen(),
  };

  for (final dark in [false, true]) {
    for (final scale in [1.3, 2.0]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} fits 320dp at ${scale}x text (${dark ? 'dark' : 'light'})', (tester) async {
          await pumpSmall(tester, entry.value, textScale: scale, dark: dark);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('profile setup pre-fills the account name and preselects no gender', (tester) async {
    await pumpSmall(tester, const ProfileSetupScreen(), textScale: 1, dark: false);
    expect(find.widgetWithText(TextFormField, 'Alex'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rivera'), findsOneWidget);
  });

  testWidgets('profile setup: missing fields block saving', (tester) async {
    final profile = await pumpSmall(tester, const ProfileSetupScreen(), textScale: 1, dark: false);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(profile.saves, isEmpty, reason: 'no date of birth and no gender chosen');
    expect(find.text('Please choose one'), findsOneWidget);
    expect(find.text('Please choose your date of birth'), findsOneWidget);
  });

  testWidgets('goals: nothing preselected, Continue disabled until a choice', (tester) async {
    await pumpSmall(tester, const GoalsScreen(), textScale: 1, dark: false);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('profile setup: a failed server save is shown and the user stays to retry', (tester) async {
    final profile = await pumpSmall(
      tester,
      const ProfileSetupScreen(),
      textScale: 1,
      dark: false,
      existing: PlainPatient(
        id: 0,
        active: true,
        gender: 'female',
        birthDate: '1990-01-15',
        name: [PlainPatientName(givenName: 'Alex', familyName: 'Rivera')],
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(profile.saves.single, {'given': 'Alex', 'gender': 'FEMALE', 'birthDate': '1990-01-15'});
    expect(find.textContaining("couldn't save your profile"), findsOneWidget);
    expect(find.text('Tell us about you'), findsOneWidget, reason: 'stays on the form');
  });
}
