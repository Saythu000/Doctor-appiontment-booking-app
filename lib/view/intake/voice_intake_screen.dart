import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/voice_intake_viewmodel.dart';
import 'intake_completion_screen.dart';

class VoiceIntakeScreen extends StatefulWidget {
  const VoiceIntakeScreen({super.key});

  @override
  State<VoiceIntakeScreen> createState() => _VoiceIntakeScreenState();
}

class _VoiceIntakeScreenState extends State<VoiceIntakeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

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
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Color _getDotColor(String dot) {
    switch (dot) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.amber;
      case 'grey':
      default:
        return Colors.grey;
    }
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
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: Colors.amber),
                SizedBox(width: 8),
                Text('Session Expired'),
              ],
            ),
            content: const Text(
              'Your secure login session has expired. Please sign in again with DrGodly IAM to connect with the AI Voice Assistant.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A3641),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await authVm.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
                child: const Text('Sign In Again'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final profile = profileVm.currentProfile;
    final name = authVm.user?.name ?? profile?.primaryName;
    final dob = profile?.birthDate;
    final email = profile?.primaryEmail ?? authVm.user?.email;
    final phone = profile?.primaryPhone;

    await voiceVm.startCall(
      authToken: token!,
      patientName: name,
      birthDate: dob,
      email: email,
      phone: phone,
    );
  }

  void _handleEndCall() async {
    final voiceVm = Provider.of<VoiceIntakeViewModel>(context, listen: false);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final profileVm = Provider.of<ProfileViewModel>(context, listen: false);

    final token = authVm.jwtToken ?? authVm.sessionToken ?? '';

    await voiceVm.endCall(
      authToken: token,
      patientFhirId: profileVm.patientFhirId,
      orgId: authVm.orgId,
    );

    if (mounted && voiceVm.callState == VoiceCallState.completed) {
      final doctorArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IntakeCompletionScreen(
            intakeId: voiceVm.savedIntakeRecordId,
            clinicalReport: voiceVm.clinicalReport,
            doctorArgs: doctorArgs,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceVm = Provider.of<VoiceIntakeViewModel>(context);
    final isConnected = voiceVm.isCallActive;

    // Auto-scroll when messages change
    if (voiceVm.committedMessages.isNotEmpty ||
        voiceVm.pendingUser.isNotEmpty ||
        voiceVm.pendingAgent.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI Voice Intake',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF0A3641),
        actions: [
          // Status Pill (§4.2)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getDotColor(voiceVm.statusDotColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  voiceVm.statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Error banner
            if (voiceVm.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.red.shade50,
                child: Text(
                  voiceVm.errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),

            // Top visual call avatar with animated pulse
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = isConnected
                          ? 1.0 + (_pulseController.value * 0.12)
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF0A3641)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            boxShadow: isConnected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0A3641).withValues(alpha: 0.3),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : [],
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isConnected
                        ? 'DrGodly Spoken Pre-Visit Intake'
                        : 'Tap "Start Call" to begin voice intake',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Live conversation transcripts area
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  if (voiceVm.committedMessages.isEmpty &&
                      voiceVm.pendingUser.isEmpty &&
                      voiceVm.pendingAgent.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          isConnected
                              ? 'Listening for intake agent greeting...'
                              : 'Speak naturally with the AI intake specialist to review symptoms before your appointment.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  // Committed turn bubbles
                  ...voiceVm.committedMessages.map((msg) {
                    final isUser = msg.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF0A3641) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isUser
                              ? null
                              : Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Live pending patient speech recognition (§4.1)
                  if (voiceVm.pendingUser.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A3641).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                voiceVm.pendingUser,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Live pending assistant speaking token buffer (§4.1)
                  if (voiceVm.pendingAgent.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF0A3641).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          voiceVm.pendingAgent,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  // Call concluding notice
                  if (voiceVm.isBusy)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF0A3641)),
                            const SizedBox(height: 8),
                            Text(
                              voiceVm.callState == VoiceCallState.generatingReport
                                  ? 'Generating clinical report...'
                                  : 'Saving intake record...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A3641),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // In-call control dock (§5.2, §5.3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  )
                ],
              ),
              child: isConnected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute / Unmute Button (§5.3)
                        IconButton(
                          iconSize: 28,
                          icon: Icon(
                            voiceVm.isMuted ? Icons.mic_off : Icons.mic,
                            color: voiceVm.isMuted ? Colors.red : const Color(0xFF0A3641),
                          ),
                          onPressed: voiceVm.isBusy ? null : () => voiceVm.toggleMute(),
                          tooltip: voiceVm.isMuted ? 'Unmute' : 'Mute',
                        ),

                        // End Call (Red button §5.2)
                        ElevatedButton.icon(
                          onPressed: voiceVm.isBusy ? null : _handleEndCall,
                          icon: const Icon(Icons.call_end, color: Colors.white),
                          label: const Text(
                            'End Call',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),

                        // Restart Button (§5.3)
                        IconButton(
                          iconSize: 26,
                          icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                          onPressed: voiceVm.isBusy
                              ? null
                              : () {
                                  final authVm =
                                      Provider.of<AuthViewModel>(context, listen: false);
                                  final profileVm =
                                      Provider.of<ProfileViewModel>(context, listen: false);
                                  final profile = profileVm.currentProfile;
                                  voiceVm.restartCall(
                                    authToken: authVm.jwtToken ?? '',
                                    patientName: authVm.user?.name ?? profile?.primaryName,
                                    birthDate: profile?.birthDate,
                                    email: profile?.primaryEmail ?? authVm.user?.email,
                                    phone: profile?.primaryPhone,
                                  );
                                },
                          tooltip: 'Restart Call',
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: voiceVm.isBusy ? null : _handleStartCall,
                        icon: const Icon(Icons.call, color: Colors.white),
                        label: const Text(
                          'Start Call',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A3641),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
