import 'package:flutter/widgets.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_viewmodel.dart';
import 'package:phia_flutter/features/profile/data/profile_photo_store.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Signs the user out and clears every app-wide view model.
///
/// All view models are global providers, so anything not reset here survives
/// into the next user's session on the same device (chat transcripts, intake
/// ids, appointments). Always sign out through this function.
Future<void> signOutAndResetSession(BuildContext context) async {
  final activityVm = context.read<ActivityViewModel>();
  final profileVm = context.read<ProfileViewModel>();
  final bookingVm = context.read<BookingViewModel>();
  final intakeVm = context.read<IntakeViewModel>();
  final voiceVm = context.read<VoiceIntakeViewModel>();
  final settingsVm = context.read<SettingsViewModel>();
  final authVm = context.read<AuthViewModel>();

  activityVm.pauseAutoSync();
  await voiceVm.abortCall();
  voiceVm.reset();
  intakeVm.reset();
  bookingVm.reset();
  activityVm.resetState();
  profileVm.resetState();
  settingsVm.resetState();

  // The profile photo file belongs to this user too.
  await ProfilePhotoStore.deleteAll();

  await authVm.signOut();
}
