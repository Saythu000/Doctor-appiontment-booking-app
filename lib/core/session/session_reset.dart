import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/activity_viewmodel.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../viewmodel/intake_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import '../../viewmodel/voice_intake_viewmodel.dart';

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

  await authVm.signOut();
}
