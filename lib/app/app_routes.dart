/// Every screen's path, in one place. Navigate with `context.go(AppRoutes.x)`
/// (replace the whole stack) or `context.push(AppRoutes.x)` (open on top).
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';

  // Onboarding
  static const profileSetup = '/onboarding/profile';
  static const goals = '/onboarding/goals';
  static const onboardingComplete = '/onboarding/complete';

  // Main app (bottom navigation)
  static const home = '/home';

  // Booking
  static const doctors = '/booking/doctors';
  static const bookingTime = '/booking/time';
  static const bookingReview = '/booking/review';
  static const bookingConfirmed = '/booking/confirmed';
  static const appointments = '/appointments';

  // Intake
  static const chatIntake = '/intake/chat';
  static const voiceIntake = '/intake/voice';
  static const intakeComplete = '/intake/complete';

  // Profile and settings
  static const profile = '/profile';
  static const vitals = '/vitals';
  static const generalSettings = '/settings/general';
  static const units = '/settings/units';
  static const reminders = '/settings/reminders';
  static const alertLimits = '/settings/alert-limits';
}
