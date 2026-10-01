import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/intake_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import 'intake_completion_screen.dart';

class IntakeChatScreen extends StatefulWidget {
  const IntakeChatScreen({super.key});

  @override
  State<IntakeChatScreen> createState() => _IntakeChatScreenState();
}

class _IntakeChatScreenState extends State<IntakeChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);
      // If fresh screen, reset
      if (intakeVm.messages.isEmpty) {
        intakeVm.reset();
      }
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

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);
    final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);

    final token = authVm.jwtToken ?? authVm.sessionToken ?? '';

    _textController.clear();
    intakeVm.sendMessage(
      text: text,
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
    );
    _scrollToBottom();
  }

  void _handleEndChat() {
    final intakeVm = Provider.of<IntakeViewModel>(context, listen: false);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);

    if (intakeVm.messages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final token = authVm.jwtToken ?? authVm.sessionToken ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Clinical Intake?'),
        content: const Text(
          'Your conversation will be summarized into a clinical intake report for your doctor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue Chatting'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PhiaColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              intakeVm.finishIntake(
                authToken: token,
                patientFhirId: profileVm.patientFhirId,
                orgId: authVm.orgId,
              );
            },
            child: const Text('Finish & Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IntakeViewModel>(
      builder: (context, vm, child) {
        // Auto-navigate to completion screen when completed
        if (vm.state == IntakeState.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const IntakeCompletionScreen(),
              ),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 22),
                SizedBox(width: 8),
                Text('AI Pre-Visit Intake'),
              ],
            ),
            actions: [
              if (vm.state != IntakeState.saving &&
                  vm.state != IntakeState.generatingReport)
                TextButton.icon(
                  onPressed: _handleEndChat,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  label: const Text(
                    'End Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Top clinical disclaimer banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: PhiaColors.primaryCard.withOpacity(0.12),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: PhiaColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your intake summary will be reviewed directly by your doctor before consultation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PhiaColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Chat Messages List
              Expanded(
                child: vm.messages.isEmpty && vm.currentStreamingText.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: vm.messages.length +
                            (vm.currentStreamingText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < vm.messages.length) {
                            final msg = vm.messages[index];
                            return _buildMessageBubble(
                              isUser: msg.isUser,
                              content: msg.content,
                            );
                          } else {
                            // Actively streaming message bubble
                            return _buildMessageBubble(
                              isUser: false,
                              content: vm.currentStreamingText,
                              isStreaming: true,
                            );
                          }
                        },
                      ),
              ),

              // Progress banner when generating report or saving
              if (vm.state == IntakeState.generatingReport ||
                  vm.state == IntakeState.saving)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: PhiaColors.primary.withOpacity(0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PhiaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        vm.state == IntakeState.generatingReport
                            ? 'Generating clinical assessment note...'
                            : 'Saving intake record for doctor...',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PhiaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Error banner if any
              if (vm.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: PhiaColors.pulseRed.withOpacity(0.1),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                      color: PhiaColors.pulseRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Input Bar
              _buildInputArea(vm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PhiaColors.primaryCard.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 48,
                color: PhiaColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How are you feeling today?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PhiaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe your primary symptom, discomfort, or reason for consulting the doctor. Our AI clinical assistant will take initial notes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PhiaColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPromptChip("I've had a headache for 3 days"),
                _buildPromptChip("Experiencing fever and body aches"),
                _buildPromptChip("Lower back pain since yesterday"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: PhiaColors.borderSubtle),
      onPressed: () {
        _textController.text = text;
        _handleSend();
      },
    );
  }

  Widget _buildMessageBubble({
    required bool isUser,
    required String content,
    bool isStreaming = false,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? PhiaColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: PhiaColors.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isUser ? Colors.white : PhiaColors.textPrimary,
              ),
            ),
            if (isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: PhiaColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(IntakeViewModel vm) {
    final isBusy = vm.isBusy;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: PhiaColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !isBusy,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                hintText: isBusy
                    ? 'AI is preparing clinical notes...'
                    : 'Type your message...',
                hintStyle: const TextStyle(
                  color: PhiaColors.textSecondary,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: isBusy ? Colors.grey.shade100 : PhiaColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isBusy ? null : _handleSend,
            icon: Icon(
              Icons.send_rounded,
              color: isBusy ? Colors.grey : PhiaColors.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isBusy
                  ? Colors.grey.shade200
                  : PhiaColors.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
