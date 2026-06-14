import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/typography.dart';
import 'data/repository/health_repository.dart';
import 'data/repository/profile_repository.dart';
import 'data/repository/booking_repository.dart';
import 'data/service/gps_location_sensor.dart';
import 'data/service/pedometer_sensor.dart';
import 'view/auth/login_screen.dart';
import 'view/onboarding/welcome_screen.dart';
import 'view/onboarding/profile_setup_screen.dart';
import 'view/onboarding/goals_screen.dart';
import 'view/onboarding/complete_screen.dart';
import 'view/dashboard/main_navigation_shell.dart';
import 'view/dashboard/activity_tracking_screen.dart';
import 'view/profile/profile_screen.dart';
import 'view/profile/clinical_units_screen.dart';
import 'view/profile/vitals_reminders_screen.dart';
import 'view/profile/vitals_thresholds_screen.dart';
import 'view/profile/general_settings_screen.dart';
import 'view/profile/appointment_history_screen.dart';
import 'view/booking/select_specialist_screen.dart';
import 'view/booking/select_date_time_screen.dart';
import 'view/booking/review_booking_screen.dart';
import 'view/booking/booking_confirmed_screen.dart';
import 'view/splash/splash_screen.dart';
import 'viewmodel/activity_viewmodel.dart';
import 'viewmodel/profile_viewmodel.dart';
import 'viewmodel/booking_viewmodel.dart';
import 'viewmodel/settings_viewmodel.dart';
import 'viewmodel/auth_viewmodel.dart';
import 'data/repository/auth_repository.dart';
import 'data/service/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ActivityViewModel(
            pedometer: PedometerSensor(),
            gps: GPSLocationSensor(),
            repository: HealthRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileViewModel(
            profileRepository: ProfileRepository(),
            healthRepository: HealthRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BookingViewModel(
            bookingRepository: BookingRepository(),
            healthRepository: HealthRepository(),
            profileRepository: ProfileRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(
            healthRepository: HealthRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            authRepository: AuthRepository(),
            healthRepository: HealthRepository(),
          ),
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
      title: 'DRGODLY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: PhiaTypography.textTheme,
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/goals': (context) => const GoalsScreen(),
        '/complete': (context) => const CompleteScreen(),
        '/dashboard': (context) => const MainNavigationShell(),
        '/profile': (context) => const ProfileScreen(),
        '/activity_tracking': (context) => const ActivityTrackingScreen(),
        '/booking_specialist': (context) => const SelectSpecialistScreen(),
        '/booking_date_time': (context) => const SelectDateTimeScreen(),
        '/booking_review': (context) => const ReviewBookingScreen(),
        '/booking_confirmed': (context) => const BookingConfirmedScreen(),
        '/clinical_units': (context) => const ClinicalUnitsScreen(),
        '/vitals_reminders': (context) => const VitalsRemindersScreen(),
        '/vitals_thresholds': (context) => const VitalsThresholdsScreen(),
        '/general_settings': (context) => const GeneralSettingsScreen(),
        '/appointment_history': (context) => const AppointmentHistoryScreen(),
      },
    );
  }
}
