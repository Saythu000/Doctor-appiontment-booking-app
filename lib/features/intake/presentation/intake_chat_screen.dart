import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/intake_completion_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/chat_bubbles.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/chat_input_bar.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/intake_notice.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:provider/provider.dart';

/// Pre-visit intake by chat: the assistant asks a few questions about how the
/// patient feels; when finished, a summary is saved for the doctor.
class IntakeChatScreen extends StatefulWidget {
  const IntakeChatScreen({super.key});

  @override
  State<IntakeChatScreen> createState() => _IntakeChatScreenState();
}

class _IntakeChatScreenState extends State<IntakeChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _navigatedToCompletion = false;
  bool _staleCompletedOnEntry = false;

  @override
  void initState() {
    super.initState();
    // A "completed" state left over from an earlier intake is reset in the
    // post-frame callback below; until then the first build must not treat
    // it as this conversation finishing.
    _staleCompletedOnEntry = Provider.of<IntakeViewModel>(context, listen: false).state ==
        IntakeState.completed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);
      final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
      // Ensure patient profile is fully loaded for context header (§2.0)
      if (profileVm.currentProfile == null) {
        profileVm.fetchOrInitProfile();
      }
      // Start a fresh conversation unless one is still in progress. A
      // completed (or failed) intake from earlier must not carry over, or
      // the screen jumped straight to the completion page on every visit.
      if (intakeVm.messages.isEmpty ||
          intakeVm.state == IntakeState.completed) {
        intakeVm.reset();
      }
      _staleCompletedOnEntry = false;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    // Clear first, so a second tap while the token renews can't resend it.
    _textController.clear();

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
    final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);

    // The Better Auth JWT lives only minutes: renew it if it has expired.
    final token = await authVm.validJwt() ?? '';
    if (!mounted) return;

    // Extract patient details for first-turn context header (text guide §2.0)
    // 1. name: Better Auth display name or fallback to Patient.name / cached name
    final patientProfile = profileVm.currentProfile;
    final displayName = authVm.user?.name ??
        (patientProfile?.primaryName.isNotEmpty == true ? patientProfile!.primaryName : null);
    final birthDate = patientProfile?.birthDate;

    // 2. email: Lowest-rank email entry from telecom or auth account
    String? email = patientProfile?.primaryEmail;
    if (email == null || email.isEmpty) {
      email = authVm.user?.email;
    }

    // 3. phone: Lowest-rank phone entry from telecom
    String? phone = patientProfile?.primaryPhone;
    if (phone != null && phone.isEmpty) {
      phone = null;
    }

    intakeVm.sendMessage(
      text: text,
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
      patientName: displayName,
      birthDate: birthDate,
      email: email,
      phone: phone,
    );
    _scrollToBottom();
  }

  Future<void> _handleRetry() async {
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
    final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);

    final token = await authVm.validJwt() ?? '';
    if (!mounted) return;
    final patientProfile = profileVm.currentProfile;
    final displayName = authVm.user?.name ??
        (patientProfile?.primaryName.isNotEmpty == true ? patientProfile!.primaryName : null);
    final birthDate = patientProfile?.birthDate;

    String? email = patientProfile?.primaryEmail;
    if (email == null || email.isEmpty) {
      email = authVm.user?.email;
    }

    String? phone = patientProfile?.primaryPhone;
    if (phone != null && phone.isEmpty) {
      phone = null;
    }

    intakeVm.retryLastMessage(
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
      patientName: displayName,
      birthDate: birthDate,
      email: email,
      phone: phone,
    );
    _scrollToBottom();
  }

  Future<void> _handleEndChat() async {
    final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);

    if (intakeVm.messages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Finish and save?',
      message: 'We will write a short summary of this conversation for your doctor.',
      confirmLabel: 'Finish & save',
      cancelLabel: 'Keep chatting',
    );
    if (!confirmed || !mounted) return;
    final token = await authVm.validJwt() ?? '';
    if (!mounted) return;
    intakeVm.finishIntake(
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorArgs = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final doctorName = doctorArgs?['name']?.toString();

    return Consumer<IntakeViewModel>(
      builder: (context, vm, child) {
        // Auto-navigate to completion screen when completed
        if (vm.state == IntakeState.completed &&
            !_staleCompletedOnEntry &&
            !_navigatedToCompletion) {
          _navigatedToCompletion = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.pushReplacement(
              AppRoutes.intakeComplete,
              extra: IntakeCompletionArgs(
                mode: IntakeMode.chat,
                doctorArgs: doctorArgs,
                intakeId: vm.savedIntakeRecordId,
                clinicalReport: vm.clinicalReport,
                turnCount: vm.messages.length,
              ),
            );
          });
        }

        final saving = vm.state == IntakeState.generatingReport || vm.state == IntakeState.saving;
        final hasConversation = vm.messages.isNotEmpty || vm.currentStreamingText.isNotEmpty;
        final waitingForFirstWords = vm.isStreaming && vm.currentStreamingText.isEmpty;
        if (hasConversation || waitingForFirstWords) _scrollToBottom();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pre-visit chat'),
            actions: [
              if (vm.messages.isNotEmpty && !saving)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: TextButton.icon(
                    onPressed: vm.isBusy ? null : _handleEndChat,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: const Text('Finish'),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (doctorName != null && doctorName.isNotEmpty)
                  IntakeNotice(
                    icon: Icons.event_note_rounded,
                    message: 'For your visit with $doctorName',
                  ),
                Expanded(
                  child: !hasConversation && !waitingForFirstWords
                      ? _ChatIntro(onPrompt: (text) {
                          _textController.text = text;
                          _handleSend();
                        })
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                          itemCount: vm.messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index < vm.messages.length) {
                              final msg = vm.messages[index];
                              final previousIsAssistant = index > 0 && !vm.messages[index - 1].isUser;
                              return ChatBubble(
                                isUser: msg.isUser,
                                text: msg.content,
                                showAvatar: msg.isUser || !previousIsAssistant,
                              );
                            }
                            // Last slot: the reply being written right now.
                            if (vm.currentStreamingText.isNotEmpty) {
                              return ChatBubble(isUser: false, text: vm.currentStreamingText, pending: true);
                            }
                            if (waitingForFirstWords) return const TypingIndicator();
                            return const SizedBox.shrink();
                          },
                        ),
                ),
                if (saving)
                  IntakeNotice(
                    showProgress: true,
                    message: vm.state == IntakeState.generatingReport
                        ? 'Writing a summary for your doctor…'
                        : 'Saving your answers…',
                  ),
                if (vm.errorMessage != null && !saving)
                  IntakeNotice(
                    tone: StatusTone.danger,
                    icon: Icons.error_outline_rounded,
                    message: vm.errorMessage!,
                    actionLabel: vm.canRetry ? 'Try again' : null,
                    onAction: vm.canRetry ? _handleRetry : null,
                  ),
                ChatInputBar(
                  controller: _textController,
                  focusNode: _focusNode,
                  busy: vm.isBusy,
                  onSend: _handleSend,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shown before the first message: what this is, and a few example answers.
class _ChatIntro extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _ChatIntro({required this.onPrompt});

  static const _examples = [
    "I've had a headache for 3 days",
    'Fever and body aches since yesterday',
    'Lower back pain when I bend',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.forum_rounded, size: 36, color: colors.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Semantics(
              header: true,
              child: Text('How are you feeling?', style: context.text.headlineSmall, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Text(
              'A few questions about how you feel. Your doctor sees a summary before your visit.',
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start with an example, or type your own:', style: context.text.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final example in _examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: OutlinedButton(
                      onPressed: () => onPrompt(example),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      ),
                      child: Text(example, style: context.text.bodyMedium!.copyWith(color: colors.textPrimary)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.textMuted),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'This is not for emergencies. If you feel very unwell, call your local emergency number.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
