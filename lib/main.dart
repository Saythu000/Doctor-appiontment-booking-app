import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phia_flutter/app/app.dart';
import 'package:phia_flutter/core/config/api_constants.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';
import 'package:phia_flutter/core/utils/app_logging.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/intake/data/intake_service.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_viewmodel.dart';
import 'package:phia_flutter/features/notifications/data/notification_service.dart';
import 'package:phia_flutter/features/profile/data/profile_repository.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/data/background_sync_service.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
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
      child: const DrGodlyApp(),
    ),
  );
}
