import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/home/presentation/dashboard_screen.dart';
import 'package:phia_flutter/features/home/presentation/widgets/body_metrics_sheet.dart';
import 'package:phia_flutter/features/notifications/presentation/notification_center_sheet.dart';
import 'package:phia_flutter/features/profile/data/profile_repository.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/domain/health_metrics.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/device_manager_sheet.dart';
import 'package:phia_flutter/features/vitals/presentation/vitals_screen.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/sync_status_strip.dart';
import 'package:provider/provider.dart';
import '../../helpers/accessibility.dart';

/// In-memory repository: signed out, so nothing reaches the network.
class _FakeHealthRepository implements HealthRepository {
  final Map<String, String> settings = {};
  final List<Map<String, dynamic>> appointments = [];
  final List<Map<String, dynamic>> notifications = [];

  @override
  Future<String?> getSetting(String key) async => settings[key];
  @override
  Future<void> saveSetting(String key, String value) async => settings[key] = value;
  @override
  Future<String?> getProfileValue(String key) async => null;
  @override
  Future<void> saveProfileValue(String key, String value) async {}
  @override
  Future<List<HealthMetric>> getRecentMetrics(String type) async => [];
  @override
  Future<void> saveMetric(HealthMetric metric) async {}
  @override
  Future<int> pruneOldMetrics({Duration maxAge = const Duration(days: 90)}) async => 0;
  @override
  Future<List<Map<String, dynamic>>> getAppointments() async => List.of(appointments);
  @override
  Future<void> saveAppointment(Map<String, dynamic> appt) async {}
  @override
  Future<List<Map<String, dynamic>>> getReminders() async => [];
  @override
  Future<Map<String, Map<String, double>>> getVitalsThresholds() async => {};
  @override
  Future<List<Map<String, dynamic>>> getInAppNotifications() async => List.of(notifications);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoProfileRepository implements ProfileRepository {
  @override
  Future<PlainPatient?> getMyProfile({String? userId, String? orgId}) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Lets a test put synced values on screen.
class _TestActivityViewModel extends ActivityViewModel {
  _TestActivityViewModel(HealthRepository repo) : super(repository: repo);

  // No 5-minute background timer in tests.
  @override
  void resumeAutoSync() {}

  void fill() {
    dashboardSteps = 8421;
    dashboardActiveTimeMins = 42;
    dashboardCalories = 1830;
    dashboardDistanceKm = 6.12;
    dashboardHr = 72;
    dashboardMinHr = 55;
    dashboardMaxHr = 131;
    dashboardHrv = 48;
    dashboardSpo2 = 97;
    dashboardSleep = 7.4;
    deepSleepMinutes = 80;
    lightSleepMinutes = 250;
    remSleepMinutes = 90;
    awakeMinutes = 24;
    userWeight = 72;
    userHeight = 175;
    userAge = 34;
    isOpenWearablesSynced = true;
    lastSyncOutcome = VitalsSyncOutcome.synced;
    lastSyncAt = DateTime.now().subtract(const Duration(minutes: 6));
    notifyListeners();
  }
}

class _Env {
  final health = _FakeHealthRepository();
  late final _TestActivityViewModel activity = _TestActivityViewModel(health);
  late final SettingsViewModel settings = SettingsViewModel(healthRepository: health);
  late final BookingViewModel booking = BookingViewModel(
    bookingRepository: BookingRepository(),
    healthRepository: health,
    profileRepository: _NoProfileRepository(),
  );
  late final ProfileViewModel profile =
      ProfileViewModel(profileRepository: _NoProfileRepository(), healthRepository: health);
}

Future<_Env> _pump(
  WidgetTester tester,
  Widget Function(_Env env) screen, {
  double textScale = 1.3,
  bool dark = false,
  void Function(_Env env)? setup,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final env = _Env();
  setup?.call(env);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(authRepository: AuthRepository(), healthRepository: HealthRepository()),
        ),
        ChangeNotifierProvider<ActivityViewModel>.value(value: env.activity),
        ChangeNotifierProvider.value(value: env.settings),
        ChangeNotifierProvider.value(value: env.booking),
        ChangeNotifierProvider.value(value: env.profile),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(textScale)),
          child: screen(env),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  return env;
}

Future<void> _scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    _expectNoError(tester);
    await expectAccessible(tester);
  }
}

void _expectNoError(WidgetTester tester) {
  final e = tester.takeException();
  if (e is FlutterError) debugPrint(e.toStringDeep());
  expect(e, isNull);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final dark in [false, true]) {
    for (final scale in [1.3, 2.0]) {
      final mode = '${dark ? 'dark' : 'light'}, text x$scale';

      testWidgets('home with nothing synced fits a small phone ($mode)', (tester) async {
        await _pump(tester, (_) => const DashboardScreen(), dark: dark, textScale: scale);
        _expectNoError(tester);
        await expectAccessible(tester);
        expect(find.text('No upcoming visits'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Not synced yet'), 200);
        // Bring the whole strip into view (not half under the top edge).
        await tester.ensureVisible(find.byType(SyncStatusStrip));
        await tester.pump(const Duration(milliseconds: 300));
        _expectNoError(tester);
        await expectAccessible(tester);
        // The old fake copy and pill must be gone.
        expect(find.text('Your clinical telemetry is synchronized.'), findsNothing);
        expect(find.text('Active'), findsNothing);
        await tester.scrollUntilVisible(find.text('Not set'), 200); // BMI unknown
        _expectNoError(tester);
        await expectAccessible(tester);
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('home with a visit and synced data fits ($mode)', (tester) async {
        final start = DateTime.now().add(const Duration(days: 1));
        final env = await _pump(
          tester,
          (_) => const DashboardScreen(),
          dark: dark,
          textScale: scale,
          setup: (env) {
            env.health.appointments.add({
              'id': 'a1',
              'practitioner_name': 'Dr. Asha Rao',
              'practitioner_role': '',
              'practitioner_image': '',
              'start_time': start.toUtc().toIso8601String(),
              'status': 'booked',
              'is_virtual': 1,
            });
            // The last refresh failed: Home must say the list may be stale.
            env.booking.appointmentsError = "Couldn't refresh";
          },
        );
        env.activity.fill();
        await tester.pump(const Duration(seconds: 1));
        _expectNoError(tester);
        await expectAccessible(tester);
        await tester.scrollUntilVisible(find.text('Dr. Asha Rao'), 200);
        expect(find.text('AR'), findsOneWidget); // initials, no stock photo
        expect(find.textContaining('may be out of date'), findsOneWidget);
        await tester.scrollUntilVisible(find.textContaining('Synced from Health Connect'), 200);
        _expectNoError(tester);
        await expectAccessible(tester);
        await _scrollThrough(tester);
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('vitals tab fits, empty and synced ($mode)', (tester) async {
        final env = await _pump(tester, (_) => const VitalsScreen(isTab: true), dark: dark, textScale: scale);
        _expectNoError(tester);
        await expectAccessible(tester);
        expect(find.text('--'), findsWidgets);
        env.activity.fill();
        await tester.pump(const Duration(seconds: 1));
        _expectNoError(tester);
        await expectAccessible(tester);
        await tester.scrollUntilVisible(find.textContaining('Awake'), 200);
        _expectNoError(tester);
        await expectAccessible(tester);
        await _scrollThrough(tester);
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('device and alerts sheets fit ($mode)', (tester) async {
        await _pump(
          tester,
          (_) => Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => DeviceManagerSheet.show(context), child: const Text('device')),
                  TextButton(onPressed: () => showNotificationCenter(context), child: const Text('alerts')),
                ],
              ),
            ),
          ),
          dark: dark,
          textScale: scale,
          setup: (env) => env.health.notifications.addAll([
            {
              'id': 'n1',
              'title': 'Vitals Warning: Heart Rate',
              'body': 'Your heart rate of 130 BPM is outside the safe range (50-100 BPM).',
              'type': 'VITALS_WARNING',
              'timestamp': DateTime.now().toIso8601String(),
              'is_read': 0,
            },
            {
              'id': 'n2',
              'title': 'Something new',
              'body': 'Unknown type falls back to a neutral style.',
              'type': 'NEW_TYPE',
              'timestamp': 'not a date',
              'is_read': 1,
            },
          ]),
        );
        await tester.tap(find.text('device'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        _expectNoError(tester);
        await expectAccessible(tester);
        expect(find.text('Health Connect'), findsOneWidget);
        Navigator.of(tester.element(find.text('Health Connect'))).pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('alerts'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        _expectNoError(tester);
        await expectAccessible(tester);
        expect(find.text('Vitals'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }

  testWidgets('body sheet stays open on invalid input and converts units', (tester) async {
    final env = await _pump(
      tester,
      (env) => Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showBodyMetricsSheet(context), child: const Text('edit')),
        ),
      ),
      setup: (env) => env.health.settings['weightUnit'] = 'lbs',
    );
    await tester.tap(find.text('edit'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '175');
    await tester.enterText(fields.at(1), '5'); // valid: the lbs range starts at 4
    await tester.enterText(fields.at(2), '0');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Edit body details'), findsOneWidget, reason: 'invalid age keeps the sheet open');
    expect(find.textContaining('between 1 and 120'), findsOneWidget);

    await tester.enterText(fields.at(1), '154');
    await tester.enterText(fields.at(2), '34');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(seconds: 1)); // save finishes, sheet starts closing
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Edit body details'), findsNothing);
    expect(env.activity.userWeight, closeTo(69.85, 0.01)); // 154 lbs saved as kg
    expect(env.activity.userHeight, 175);
    // Signed out, so the server was not updated; the message says so.
    expect(find.textContaining('Saved on this phone'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
