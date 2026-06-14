import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';

class CompleteScreen extends StatefulWidget {
  const CompleteScreen({super.key});

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Animation 1: Linear 360-degree rotation (10s cycle)
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Animation 2: Biometric scan-line vertical slide (3s cycle)
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    // Animation 3: Soft pulsing scale effect (1.5s cycle, auto-reversing)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = Provider.of<ProfileViewModel>(context);
    final activityVM = Provider.of<ActivityViewModel>(context);
    
    // Extract dynamic patient info
    final String givenName = profileVM.currentProfile?.name?.firstOrNull?.givenName ?? '';
    final String familyName = profileVM.currentProfile?.name?.firstOrNull?.familyName ?? '';
    final String displayName = (givenName.isEmpty && familyName.isEmpty)
        ? 'PATIENT'
        : '${givenName} ${familyName}'.trim();
    
    final String gender = profileVM.currentProfile?.gender ?? 'MALE';
    final String heightStr = '${activityVM.userHeight.toStringAsFixed(0)} CM';
    final String weightStr = '${activityVM.userWeight.toStringAsFixed(1)} KG';
    final String ageStr = '${activityVM.userAge} YRS';

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Ambient Background Grid Overlay (40px x 40px lines)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(
                painter: AmbientGridPainter(),
              ),
            ),
          ),

          // 2. Fixed Top App Bar Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'DRGODLY',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 24,
                            letterSpacing: 4.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Scrolling Content Canvas
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 88, bottom: 88, left: 24, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),

                  // Success Indicators: Custom Spinning outer circle + check badge
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Spinning Sweep Gradient Calibration Ring (uniform circle, safe border paint)
                        RotationTransition(
                          turns: _rotationController,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.60),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                                stops: const [0.25, 1.0],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 97,
                                height: 97,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black, // Dark mask to leave a 1.5px ring
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Soft pulsing center circle
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.task_alt,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mission success labels
                  Center(
                    child: Text(
                      'PATIENT READY',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 36,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'REGISTRATION COMPLETE. CLINICAL INTAKE SYNCHRONIZED SECURELY.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Biometric Summary Bento Card (with Dot-Matrix & Sliding Scan-Line)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0E0F),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.0),
                    ),
                    child: Stack(
                      children: [
                        // Dot Matrix texture
                        const Positioned.fill(
                          child: ClipRect(
                            child: Opacity(
                              opacity: 0.4,
                              child: DotMatrixBackground(child: SizedBox.shrink()),
                            ),
                          ),
                        ),

                        // Active sliding vertical Scan-Line
                        Positioned.fill(
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: _scanAnimation,
                              builder: (context, child) {
                                return Align(
                                  alignment: Alignment(0.0, -1.0 + _scanAnimation.value * 2.0),
                                  child: Container(
                                    height: 2,
                                    width: double.infinity,
                                    color: Colors.white.withValues(alpha: 0.40),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Biological Stats Content Padding
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PATIENT SUMMARY',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: Colors.white70,
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 24, thickness: 1.0),
                              const SizedBox(height: 8),
                              
                              // 2x2 Bento details
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 2.0,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                children: [
                                  _buildSummaryItem('Name', displayName),
                                  _buildSummaryItem('Gender', gender),
                                  _buildSummaryItem('Height', heightStr),
                                  _buildSummaryItem('Weight', weightStr),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Actions Area: flat rectangle CTAs
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CONTINUE',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 16, color: Colors.black),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Minimalist Background Painter to render the clean 40px lines grid
class AmbientGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    double spacing = 40.0;

    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
