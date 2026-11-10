import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/features/auth/presentation/login_screen.dart';
import 'package:phia_flutter/features/booking/presentation/appointment_history_screen.dart';
import 'package:phia_flutter/features/booking/presentation/booking_confirmed_screen.dart';
import 'package:phia_flutter/features/booking/presentation/review_booking_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_date_time_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_specialist_screen.dart';
import 'package:phia_flutter/features/home/presentation/main_navigation_shell.dart';
import 'package:phia_flutter/features/intake/presentation/intake_chat_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_completion_screen.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_screen.dart';
import 'package:phia_flutter/features/onboarding/complete_screen.dart';
import 'package:phia_flutter/features/onboarding/goals_screen.dart';
import 'package:phia_flutter/features/onboarding/profile_setup_screen.dart';
import 'package:phia_flutter/features/onboarding/welcome_screen.dart';
import 'package:phia_flutter/features/profile/presentation/profile_screen.dart';
import 'package:phia_flutter/features/settings/presentation/alert_limits_screen.dart';
import 'package:phia_flutter/features/settings/presentation/clinical_units_screen.dart';
import 'package:phia_flutter/features/settings/presentation/general_settings_screen.dart';
import 'package:phia_flutter/features/settings/presentation/reminders_screen.dart';
import 'package:phia_flutter/features/splash/splash_screen.dart';
import 'package:phia_flutter/features/vitals/presentation/vitals_screen.dart';

/// The app's navigation map.
///
/// The splash screen decides where a user goes (welcome, onboarding or home)
/// after checking the stored session, so there is no global redirect here.
GoRouter buildRouter() {
  GoRoute page(String path, Widget Function(GoRouterState state) build) =>
      GoRoute(path: path, builder: (context, state) => build(state));

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      page(AppRoutes.splash, (_) => const SplashScreen()),
      page(AppRoutes.welcome, (_) => const WelcomeScreen()),
      page(AppRoutes.login, (_) => const LoginScreen()),
      page(AppRoutes.profileSetup, (_) => const ProfileSetupScreen()),
      page(AppRoutes.goals, (_) => const GoalsScreen()),
      page(AppRoutes.onboardingComplete, (_) => const CompleteScreen()),
      page(AppRoutes.home, (_) => const MainNavigationShell()),
      page(AppRoutes.profile, (_) => const ProfileScreen()),
      page(AppRoutes.vitals, (_) => const VitalsScreen()),
      page(AppRoutes.doctors, (_) => const SelectSpecialistScreen()),
      page(AppRoutes.bookingTime, (_) => const SelectDateTimeScreen()),
      page(AppRoutes.bookingReview, (_) => const ReviewBookingScreen()),
      page(AppRoutes.bookingConfirmed, (_) => const BookingConfirmedScreen()),
      page(AppRoutes.appointments, (_) => const AppointmentHistoryScreen()),
      page(AppRoutes.chatIntake, (_) => const IntakeChatScreen()),
      page(AppRoutes.voiceIntake, (_) => const VoiceIntakeScreen()),
      page(AppRoutes.intakeComplete, (state) {
        final args = state.extra is IntakeCompletionArgs
            ? state.extra! as IntakeCompletionArgs
            : const IntakeCompletionArgs(mode: IntakeMode.chat);
        return IntakeCompletionScreen(args: args);
      }),
      page(AppRoutes.generalSettings, (_) => const GeneralSettingsScreen()),
      page(AppRoutes.units, (_) => const ClinicalUnitsScreen()),
      page(AppRoutes.reminders, (_) => const RemindersScreen()),
      page(AppRoutes.alertLimits, (_) => const AlertLimitsScreen()),
    ],
    // Unknown links (for example an old notification) go to the start screen.
    errorBuilder: (context, state) => const SplashScreen(),
  );
}
