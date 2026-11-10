import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phia_flutter/core/config/api_constants.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';
import 'package:phia_flutter/core/theme/colors.dart';
import 'package:phia_flutter/core/theme/typography.dart';
import 'package:phia_flutter/core/utils/app_logging.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/auth/presentation/login_screen.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/features/booking/presentation/appointment_history_screen.dart';
import 'package:phia_flutter/features/booking/presentation/booking_confirmed_screen.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/review_booking_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_date_time_screen.dart';
import 'package:phia_flutter/features/booking/presentation/select_specialist_screen.dart';
import 'package:phia_flutter/features/home/presentation/main_navigation_shell.dart';
import 'package:phia_flutter/features/intake/data/intake_service.dart';
import 'package:phia_flutter/features/intake/presentation/intake_chat_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_completion_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_screen.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_viewmodel.dart';
import 'package:phia_flutter/features/notifications/data/notification_service.dart';
import 'package:phia_flutter/features/onboarding/complete_screen.dart';
import 'package:phia_flutter/features/onboarding/goals_screen.dart';
import 'package:phia_flutter/features/onboarding/profile_setup_screen.dart';
import 'package:phia_flutter/features/onboarding/welcome_screen.dart';
import 'package:phia_flutter/features/profile/data/profile_repository.dart';
import 'package:phia_flutter/features/profile/presentation/profile_screen.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/alert_limits_screen.dart';
import 'package:phia_flutter/features/settings/presentation/clinical_units_screen.dart';
import 'package:phia_flutter/features/settings/presentation/general_settings_screen.dart';
import 'package:phia_flutter/features/settings/presentation/reminders_screen.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/splash/splash_screen.dart';
import 'package:phia_flutter/features/vitals/data/background_sync_service.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/vitals_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  silenceDebugPrintInRelease();
  WidgetsFlutterBinding.ensureInitialized();
  // Fast, prompt-free setup only. Permission requests happen later, in
  // context, from the dashboard (never before the first frame).
  await BackgroundSyncService.initialize();
  await NotificationService.instance.init();

  final healthRepo = HealthRepository();
  try {
    // Remove plaintext credentials written by older app versions.
    await healthRepo.purgeLegacyPlaintextCredentials();
  } catch (_) {
    // Never block startup; getSetting() migrates lazily as a fallback.
  }
  final savedToken = await healthRepo.getSetting('iam_jwt_token');
  if (savedToken != null && savedToken.isNotEmpty) {
    FhirApiClient().configure(
      baseUrl: ApiConstants.fhirGqlUrl,
      token: savedToken,
    );
    // Background vitals upload only makes sense for a signed-in user.
    // (Sign-out cancels it; login schedules it again.)
    unawaited(BackgroundSyncService.schedulePeriodicSync());
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ActivityViewModel(
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
        ChangeNotifierProvider(
          create: (_) => IntakeViewModel(
            intakeService: IntakeService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => VoiceIntakeViewModel(),
        ),
      ],
      child: const PhiaApp(),
    ),
  );
}

class PhiaApp extends StatefulWidget {
  const PhiaApp({super.key});

  @override
  State<PhiaApp> createState() => _PhiaAppState();
}

class _PhiaAppState extends State<PhiaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final activityVm = context.read<ActivityViewModel>();
    if (state == AppLifecycleState.resumed) {
      activityVm.resumeAutoSync();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      activityVm.pauseAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'DrGodly',
        debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: PhiaColors.background,
        colorScheme: const ColorScheme.light(
          primary: PhiaColors.primary,
          secondary: PhiaColors.primaryCard,
          error: PhiaColors.pulseRed,
          onSurface: PhiaColors.textPrimary,
        ),
        cardTheme: CardThemeData(
          color: PhiaColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PhiaColors.borderSubtle),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: PhiaColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        '/activity_tracking': (context) => const VitalsScreen(),
        '/booking_specialist': (context) => const SelectSpecialistScreen(),
        '/booking_date_time': (context) => const SelectDateTimeScreen(),
        '/booking_review': (context) => const ReviewBookingScreen(),
        '/booking_confirmed': (context) => const BookingConfirmedScreen(),
        '/clinical_units': (context) => const ClinicalUnitsScreen(),
        '/vitals_reminders': (context) => const RemindersScreen(),
        '/vitals_thresholds': (context) => const AlertLimitsScreen(),
        '/general_settings': (context) => const GeneralSettingsScreen(),
        '/appointment_history': (context) => const AppointmentHistoryScreen(),
        '/intake': (context) => const IntakeChatScreen(),
        '/voice_intake': (context) => const VoiceIntakeScreen(),
        '/intake_completion': (context) => const IntakeCompletionScreen(),
      },
    );
  }
}
