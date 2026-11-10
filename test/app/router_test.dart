import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/app/router.dart';

void main() {
  test('every app route is registered exactly once', () {
    const all = [
      AppRoutes.splash, AppRoutes.welcome, AppRoutes.login, AppRoutes.profileSetup,
      AppRoutes.goals, AppRoutes.onboardingComplete, AppRoutes.home, AppRoutes.doctors,
      AppRoutes.bookingTime, AppRoutes.bookingReview, AppRoutes.bookingConfirmed,
      AppRoutes.appointments, AppRoutes.chatIntake, AppRoutes.voiceIntake,
      AppRoutes.intakeComplete, AppRoutes.profile, AppRoutes.vitals,
      AppRoutes.generalSettings, AppRoutes.units, AppRoutes.reminders, AppRoutes.alertLimits,
    ];
    final router = buildRouter();
    final paths = router.configuration.routes.whereType<GoRoute>().map((r) => r.path).toList();
    for (final p in all) {
      expect(paths.where((x) => x == p), hasLength(1), reason: p);
    }
    expect(all.toSet(), hasLength(all.length), reason: 'paths must be unique');
    router.dispose();
  });
}
