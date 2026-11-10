import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/auth/presentation/session_reset.dart';
import 'package:phia_flutter/features/intake/presentation/intake_completion_screen.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/call_status_pill.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/chat_bubbles.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/intake_notice.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/voice_call_dock.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/voice_orb.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:provider/provider.dart';

/// Pre-visit intake by voice call with the DrGodly assistant.
class VoiceIntakeScreen extends StatefulWidget {
  const VoiceIntakeScreen({super.key});

  @override
  State<VoiceIntakeScreen> createState() => _VoiceIntakeScreenState();
}

class _VoiceIntakeScreenState extends State<VoiceIntakeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  // Cached so dispose() can stop the call without touching context.
  late final VoiceIntakeViewModel _voiceVm;
  VoiceCallState? _lastCallState;
  bool _navigatedToCompletion = false;

  @override
  void initState() {
    super.initState();
    _voiceVm = Provider.of<VoiceIntakeViewModel>(context, listen: false);
    _lastCallState = _voiceVm.callState;
    // The agent can end the call itself (status_end / goodbye). Navigate on
    // the state change, not only after the End button, or the patient was
    // left on a finished call screen.
    _voiceVm.addListener(_onVoiceStateChanged);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
      if (profileVm.currentProfile == null) {
        profileVm.fetchOrInitProfile();
      }
      // Auto-start call on screen load per guide §2 & web app parity
      final voiceVm = Provider.of<VoiceIntakeViewModel>(context, listen: false);
      if (!voiceVm.isCallActive && !voiceVm.isBusy) {
        _handleStartCall();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceVm.removeListener(_onVoiceStateChanged);
    // Leaving the screen must never leave the microphone streaming.
    if (_voiceVm.isCallActive) {
      _voiceVm.abortCall();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Voice guide §5.4: when the app goes to the background mid-call, stop
  /// capturing; the guide's suggested default is to treat it as "End Call"
  /// (which saves the conversation if anything was said).
  /// `paused` (not `inactive`) is used so the mic-permission dialog and the
  /// notification shade do not end the call.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _voiceVm.callState == VoiceCallState.connected &&
        !_voiceVm.isBusy) {
      _handleEndCall();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleStartCall() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
    final voiceVm = Provider.of<VoiceIntakeViewModel>(context, listen: false);

    // Refresh token right before connect (§2.1)
    String? token = await authVm.refreshToken();
    if (!AuthViewModel.isJwtValid(token)) {
      if (AuthViewModel.isJwtValid(authVm.jwtToken)) {
        token = authVm.jwtToken;
      } else if (AuthViewModel.isJwtValid(authVm.idToken)) {
        token = authVm.idToken;
      }
    }

    if (!AuthViewModel.isJwtValid(token)) {
      if (!mounted) return;
      final signIn = await confirmAction(
        context,
        title: 'Please sign in again',
        message: 'For your security, your session has ended. Sign in again to start the voice call.',
        confirmLabel: 'Sign in again',
        cancelLabel: 'Not now',
      );
      if (!signIn || !mounted) return;
      await signOutAndResetSession(context);
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    final profile = profileVm.currentProfile;
    final name = authVm.user?.name ?? profile?.primaryName;
    final dob = profile?.birthDate;
    final email = profile?.primaryEmail ?? authVm.user?.email;
    final phone = profile?.primaryPhone;

    await voiceVm.startCall(
      authToken: token!,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
      patientName: name,
      birthDate: dob,
      email: email,
      phone: phone,
    );
  }

  /// Starting over deletes what the patient already said; ask first.
  Future<bool> _confirmDiscardConversation() async {
    return confirmAction(
      context,
      title: 'Start over?',
      message: 'Everything said in this call will be deleted and not sent to your doctor.',
      confirmLabel: 'Start over',
      cancelLabel: 'Keep',
      destructive: true,
    );
  }

  void _handleEndCall() async {
    final voiceVm = Provider.of<VoiceIntakeViewModel>(context, listen: false);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);

    final token = authVm.jwtToken ?? '';

    await voiceVm.endCall(
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
    );

    // Navigation to the completion screen happens in _onVoiceStateChanged.
  }

  void _onVoiceStateChanged() {
    final state = _voiceVm.callState;
    final becameCompleted =
        state == VoiceCallState.completed && _lastCallState != VoiceCallState.completed;
    _lastCallState = state;
    if (!becameCompleted || _navigatedToCompletion) return;
    _navigatedToCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final doctorArgs = GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.pushReplacement(
        AppRoutes.intakeComplete,
        extra: IntakeCompletionArgs(
          mode: IntakeMode.voice,
          intakeId: _voiceVm.savedIntakeRecordId,
          clinicalReport: _voiceVm.clinicalReport,
          doctorArgs: doctorArgs,
          turnCount: _voiceVm.committedMessages.length,
        ),
      );
    });
  }

  void _handleRestart() async {
    final voiceVm = _voiceVm;
    if (voiceVm.committedMessages.isNotEmpty && !await _confirmDiscardConversation()) {
      return;
    }
    if (!mounted) return;
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
    final profile = profileVm.currentProfile;
    voiceVm.restartCall(
      authToken: authVm.jwtToken ?? '',
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
      patientName: authVm.user?.name ?? profile?.primaryName,
      birthDate: profile?.birthDate,
      email: profile?.primaryEmail ?? authVm.user?.email,
      phone: profile?.primaryPhone,
    );
  }

  Future<void> _handleBack() async {
    final leave = await confirmAction(
      context,
      title: 'End voice intake?',
      message: 'Leaving now stops the call. This conversation will not be saved.',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (!leave) return;
    await _voiceVm.abortCall();
    if (mounted) Navigator.of(context).pop();
  }

  static OrbMode _orbMode(VoiceIntakeViewModel vm) {
    switch (vm.callState) {
      case VoiceCallState.connecting:
        return OrbMode.connecting;
      case VoiceCallState.connected:
        if (vm.isMuted) return OrbMode.muted;
        if (vm.pendingAgent.isNotEmpty || vm.statusLabel.startsWith('Speaking')) return OrbMode.speaking;
        if (vm.statusLabel.startsWith('Thinking') || vm.statusLabel.startsWith('Connecting')) {
          return OrbMode.connecting;
        }
        return OrbMode.listening;
      case VoiceCallState.ending:
      case VoiceCallState.generatingReport:
      case VoiceCallState.saving:
        return OrbMode.working;
      case VoiceCallState.offline:
      case VoiceCallState.completed:
      case VoiceCallState.error:
        return OrbMode.idle;
    }
  }

  static StatusTone _statusTone(String dot) => switch (dot) {
        'green' => StatusTone.success,
        'amber' => StatusTone.warning,
        _ => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final voiceVm = Provider.of<VoiceIntakeViewModel>(context);
    final inCall = voiceVm.isCallActive;
    final hasTranscript = voiceVm.committedMessages.isNotEmpty ||
        voiceVm.pendingUser.isNotEmpty ||
        voiceVm.pendingAgent.isNotEmpty;
    if (hasTranscript) _scrollToBottom();

    final working = voiceVm.callState == VoiceCallState.generatingReport ||
        voiceVm.callState == VoiceCallState.saving;
    final hint = switch (voiceVm.callState) {
      VoiceCallState.connected when voiceVm.isMuted => 'Your microphone is off. Tap Unmute to talk.',
      VoiceCallState.connected => 'Speak naturally. Tap End call when you are done.',
      VoiceCallState.connecting => 'Connecting you to the assistant…',
      _ => 'Talk with the assistant about how you feel. Your doctor sees a summary.',
    };

    // On a small phone with large text the orb and status scroll with the
    // transcript instead of staying pinned, so nothing gets cut off.
    final compact = MediaQuery.textScalerOf(context).scale(14) > 20 ||
        MediaQuery.sizeOf(context).height < 560;
    final Widget header = Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Column(
                  children: [
                    VoiceOrb(mode: _orbMode(voiceVm), size: compact ? 88 : (hasTranscript ? 104 : 136)),
                    const SizedBox(height: AppSpacing.md),
                    CallStatusPill(label: voiceVm.statusLabel, tone: _statusTone(voiceVm.statusDotColor)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(hint, style: context.text.bodyMedium, textAlign: TextAlign.center),
                  ],
                ),
              );

    return PopScope(
      canPop: !inCall,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Voice intake')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (voiceVm.errorMessage != null)
                IntakeNotice(
                  tone: StatusTone.danger,
                  icon: Icons.error_outline_rounded,
                  message: voiceVm.errorMessage!,
                  actionLabel: 'Switch to chat',
                  actionIcon: Icons.chat_bubble_outline_rounded,
                  onAction: () {
                    final doctorArgs = GoRouterState.of(context).extra as Map<String, dynamic>?;
                    context.pushReplacement(AppRoutes.chatIntake, extra: doctorArgs);
                  },
                ),
              if (!compact) ...[header, Divider(height: 1, color: context.colors.border)],
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (compact) header,
                    if (!hasTranscript)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Text(
                          inCall
                              ? 'The assistant will greet you in a moment. What you both say appears here.'
                              : 'What you and the assistant say will appear here.',
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (var i = 0; i < voiceVm.committedMessages.length; i++)
                      ChatBubble(
                        isUser: voiceVm.committedMessages[i].role == 'user',
                        text: voiceVm.committedMessages[i].content,
                        showAvatar: voiceVm.committedMessages[i].role == 'user' ||
                            i == 0 ||
                            voiceVm.committedMessages[i - 1].role == 'user',
                      ),
                    if (voiceVm.pendingUser.isNotEmpty)
                      ChatBubble(isUser: true, text: voiceVm.pendingUser, pending: true),
                    if (voiceVm.pendingAgent.isNotEmpty)
                      ChatBubble(isUser: false, text: voiceVm.pendingAgent, pending: true),
                  ],
                ),
              ),
              if (working)
                IntakeNotice(
                  showProgress: true,
                  message: voiceVm.callState == VoiceCallState.generatingReport
                      ? 'Writing a summary for your doctor…'
                      : 'Saving your conversation…',
                ),
              const SizedBox(height: AppSpacing.sm),
              VoiceCallDock(
                inCall: inCall,
                busy: voiceVm.isBusy,
                muted: voiceVm.isMuted,
                canRetrySave: voiceVm.canRetrySave,
                onToggleMute: voiceVm.toggleMute,
                onEnd: _handleEndCall,
                onRestart: _handleRestart,
                onStart: _handleStartCall,
                onRetrySave: () => voiceVm.retrySave(
                  authToken: Provider.of<AuthViewModel>(context, listen: false).jwtToken ?? '',
                ),
                onDiscard: () async {
                  if (await _confirmDiscardConversation()) _handleStartCall();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
