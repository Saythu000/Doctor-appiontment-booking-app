import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/typography.dart';
import 'data/repository/health_repository.dart';
import 'data/service/camera_ppg_sensor.dart';
import 'data/service/gps_location_sensor.dart';
import 'data/service/pedometer_sensor.dart';
import 'view/auth/login_screen.dart';
import 'view/onboarding/welcome_screen.dart';
import 'view/onboarding/profile_setup_screen.dart';
import 'view/onboarding/goals_screen.dart';
import 'view/onboarding/complete_screen.dart';
import 'view/dashboard/main_navigation_shell.dart';
import 'view/dashboard/activity_tracking_screen.dart';
import 'view/workout/workout_library_screen.dart';
import 'view/workout/live_workout_screen.dart';
import 'view/profile/profile_screen.dart';
import 'view/booking/select_specialist_screen.dart';
import 'view/booking/select_date_time_screen.dart';
import 'view/booking/review_booking_screen.dart';
import 'view/booking/booking_confirmed_screen.dart';
import 'view/assistant/ai_assistant_screen.dart';
import 'viewmodel/health_viewmodel.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HealthViewModel(
            pedometer: PedometerSensor(),
            gps: GPSLocationSensor(),
            ppg: CameraPPGSensor(),
            repository: HealthRepository(),
          )..initDashboard()..startStepsTracking(),
        ),
      ],
      child: const PhiaApp(),
    ),
  );
}

class PhiaApp extends StatelessWidget {
  const PhiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: PhiaTypography.textTheme,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/goals': (context) => const GoalsScreen(),
        '/complete': (context) => const CompleteScreen(),
        '/dashboard': (context) => const MainNavigationShell(),
        '/profile': (context) => const ProfileScreen(),
        '/activity_tracking': (context) => const ActivityTrackingScreen(),
        '/workout_library': (context) => const WorkoutLibraryScreen(),
        '/live_workout': (context) => const LiveWorkoutScreen(),
        '/booking_specialist': (context) => const SelectSpecialistScreen(),
        '/booking_date_time': (context) => const SelectDateTimeScreen(),
        '/booking_review': (context) => const ReviewBookingScreen(),
        '/booking_confirmed': (context) => const BookingConfirmedScreen(),
        '/assistant': (context) => const PhiaAiAssistantScreen(),
      },
    );
  }
}
