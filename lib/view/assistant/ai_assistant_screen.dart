import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/health_viewmodel.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool showNutrition;
  final bool showBiometrics;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.showNutrition = false,
    this.showBiometrics = false,
  });
}

class PhiaAiAssistantScreen extends StatefulWidget {
  const PhiaAiAssistantScreen({super.key});

  @override
  State<PhiaAiAssistantScreen> createState() => _PhiaAiAssistantScreenState();
}

class _PhiaAiAssistantScreenState extends State<PhiaAiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Pulsing animation controller for the green ONLINE status dot
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation: scale between 0.6 and 1.0 continuously
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Seed the conversation with the exact high-fidelity mockup start state
    _messages.add(
      ChatMessage(
        text: "HOW SHOULD I HANDLE RECOVERY TODAY AFTER YESTERDAY'S HIGH-INTENSITY INTERVALS?",
        isUser: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    _messages.add(
      ChatMessage(
        text: "BASED ON YOUR VO2 MAX (58.4) AND RECENT HIP MOBILITY SESSIONS, I RECOMMEND THE DYNAMIC FLOW TO OPTIMIZE RECOVERY.",
        isUser: false,
        timestamp: DateTime.now(),
        showNutrition: true,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(HealthViewModel healthVM, [String? textOverride]) {
    final text = textOverride ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (textOverride == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulated terminal analytical pause (1200ms)
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        final query = text.toLowerCase();
        String response = '';
        bool triggerNutrition = false;
        bool triggerBiometrics = false;

        int steps = healthVM.liveSteps > 0 ? healthVM.liveSteps : healthVM.dashboardSteps;

        if (query.contains('step') || query.contains('walk')) {
          response = 'YOUR CURRENT DAILY STEP LOG STANDS AT $steps STEPS. THIS COMPLETES ${((steps / 10000.0) * 100).toStringAsFixed(0)}% OF YOUR 10,000 STEP PHYSICAL THRESHOLD FOR CY24.';
          triggerBiometrics = true;
        } else if (query.contains('heart') || query.contains('bpm') || query.contains('pulse')) {
          double hr = healthVM.dashboardHr > 0 ? healthVM.dashboardHr : 68.0;
          response = 'YOUR LATEST OPTICAL PPG BIO-POLLING CAPTURED A HEART RATE OF ${hr.toStringAsFixed(0)} BPM, INDICATING STABLE CARDIOVASCULAR STEADY-STATE CALIBRATION.';
          triggerBiometrics = true;
        } else if (query.contains('diet') || query.contains('nutrition') || query.contains('food') || query.contains('plan')) {
          response = 'RECOMMENDING MACRONUTRIENT BINDING FOR POST-WORKOUT SYSTEM SYNAPSE OPTIMIZATION. ENFORCING PRO-FAT HIGHER BIOMULTIPLIERS.';
          triggerNutrition = true;
        } else if (query.contains('hrv') || query.contains('variability')) {
          double hrv = healthVM.dashboardHrv > 0 ? healthVM.dashboardHrv : 72.0;
          response = 'YOUR LOCAL HRV INDEX RECORDS ${hrv.toStringAsFixed(0)} MS (RMSSD). THIS REVEALS SATISFACTORY PARASYMPATHETIC BALANCE.';
          triggerBiometrics = true;
        } else if (query.contains('workout') || query.contains('suggest')) {
          response = 'SUGGESTING LOW-LATENCY KINETIC RECOVERY DRIFT: DYNAMIC FLOW STRETCHING PROTOCOL (45 MINS) TO RESTORE NEURO-MUSCULAR PATHWAYS.';
          triggerBiometrics = true;
        } else if (query.contains('appointment') || query.contains('check')) {
          response = 'PLATFORM REGISTRY CHECKS ACTIVE. LEAD OPERATIVE APPOINTMENT SECURED: SESSION ID BK-772 WITH COACH MARCUS TODAY.';
        } else {
          response = 'INPUT RECEIVED. LOCAL CORE SENSOR ARRAYS STAND READY. INQUIRE CONCISELY REGARDING "STEPS", "HEART RATE", "HRV PROTOCOLS" OR "DIET PLAN" TO SYNC SYSTEM ARTIFACTS.';
        }

        setState(() {
          _messages.add(
            ChatMessage(
              text: response.toUpperCase(),
              isUser: false,
              timestamp: DateTime.now(),
              showNutrition: triggerNutrition,
              showBiometrics: triggerBiometrics,
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final healthVM = context.watch<HealthViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Ambient Dot Matrix Background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 2. Main Page Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom Header Row (Menu, KINETIC, pulsing ONLINE status)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'KINETIC',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 26,
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      
                      // KNT-AI v2.1 Pulse status badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'KNT-AI v2.1',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              // Pulsing indicator dot
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ONLINE',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chat Messages Feed list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),

                // Typing/Analyzing Indicator
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Text(
                          'KNT-AI',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ANALYZING BIOMETRICS...',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bottom Controls panel
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Action Suggestion Chips
                      Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          children: [
                            _buildQuickActionChip('SUGGEST WORKOUT', healthVM),
                            const SizedBox(width: 12),
                            _buildQuickActionChip('DIET PLAN', healthVM),
                            const SizedBox(width: 12),
                            _buildQuickActionChip('CHECK APPOINTMENTS', healthVM),
                          ],
                        ),
                      ),

                      // Input Bar textfield container
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 24.0, top: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: TextField(
                                    controller: _inputController,
                                    cursorColor: Colors.white,
                                    cursorHeight: 18,
                                    cursorWidth: 2.0,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'ASK KNT-AI...',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white.withValues(alpha: 0.24),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _sendMessage(healthVM),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _sendMessage(healthVM),
                                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label, HealthViewModel healthVM) {
    return GestureDetector(
      onTap: () => _sendMessage(healthVM, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final String timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    if (msg.isUser) {
      // High-Fidelity USER Bubble Layout (desaturated grey, 85% width)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                msg.text.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'USER // $timeStr',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    } else {
      // High-Fidelity KNT-AI Bubble Layout (solid white outline, 90% width, black background)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row above bubble
            Row(
              children: [
                Text(
                  'KNT-AI',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.90,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white, width: 1.0),
              ),
              child: Stack(
                children: [
                  // Dot matrix header simulation overlay (height 40 at the top)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Opacity(
                      opacity: 0.15,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/fonts/GeistVF.ttf'), // generic asset binder pattern
                            repeat: ImageRepeat.repeat,
                            fit: BoxFit.none,
                          ),
                        ),
                        // Soft dot shader
                        child: CustomPaint(
                          painter: ChatDotPatternPainter(),
                        ),
                      ),
                    ),
                  ),

                  // Main Text Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // Sub-component 1: Daily Nutrition Recommendations
                        if (msg.showNutrition) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY NUTRITION',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Icon(
                                Icons.restaurant,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 14,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Food Plate Bento Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              children: [
                                // Grayscale post-workout meal image
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    image: const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=200'),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0,      0,      0,      1, 0,
                                      ]),
                                    ),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'POST-WORKOUT OPTIMIZATION',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'HIGH-PROTEIN SYNERGY: SALMON + QUINOA + BRAISED KALE.',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: Colors.white.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildNutrientChip('42G PRO'),
                                          const SizedBox(width: 8),
                                          _buildNutrientChip('12G FAT'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Sub-component 2: Biometric Stream
                        if (msg.showBiometrics) ...[
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.white, width: 2.0),
                              ),
                            ),
                            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BIOMETRIC STREAM',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HRV',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        Text(
                                          '72MS',
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 20,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 32),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RECOVERY',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        Text(
                                          '88%',
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 20,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'KNT-AI // $timeStr',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNutrientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// Custom Painter to draw a fine technical dot grid inside the AI bubble header
class ChatDotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    const double spacing = 8.0;
    for (double y = 2.0; y < size.height; y += spacing) {
      for (double x = 2.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
