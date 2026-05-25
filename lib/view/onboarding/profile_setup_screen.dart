import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  final _heightFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _ageFocus = FocusNode();

  bool _isHeightFocused = false;
  bool _isWeightFocused = false;
  bool _isAgeFocused = false;

  @override
  void initState() {
    super.initState();
    _heightFocus.addListener(() => setState(() => _isHeightFocused = _heightFocus.hasFocus));
    _weightFocus.addListener(() => setState(() => _isWeightFocused = _weightFocus.hasFocus));
    _ageFocus.addListener(() => setState(() => _isAgeFocused = _ageFocus.hasFocus));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  Widget _buildBentoCard({
    required String label,
    required IconData icon,
    required String placeholder,
    required String unit,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFocused ? const Color(0xFF0D0E0F) : Colors.black,
        border: Border.all(
          color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: Colors.white60,
                ),
              ),
              Icon(icon, color: Colors.white54, size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 40,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: GoogleFonts.bebasNeue(
                      fontSize: 40,
                      color: Colors.white24,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix texture background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'PHIA',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 24,
                            letterSpacing: 3.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main form content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80.0, bottom: 120.0, left: 24.0, right: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Section
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.white, width: 2.0),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATHLETE BIO-DATA',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 36,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'PHASE 02 // PHYSICAL_CALIBRATION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Grid inputs (2 Columns for Height & Weight, 1 Full for Age)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: _buildBentoCard(
                            label: 'HEIGHT',
                            icon: Icons.straighten,
                            placeholder: '000',
                            unit: 'CM',
                            controller: _heightController,
                            focusNode: _heightFocus,
                            isFocused: _isHeightFocused,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: _buildBentoCard(
                            label: 'WEIGHT',
                            icon: Icons.monitor_weight_outlined,
                            placeholder: '00.0',
                            unit: 'KG',
                            controller: _weightController,
                            focusNode: _weightFocus,
                            isFocused: _isWeightFocused,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _buildBentoCard(
                      label: 'AGE',
                      icon: Icons.calendar_today_outlined,
                      placeholder: '00',
                      unit: 'YRS',
                      controller: _ageController,
                      focusNode: _ageFocus,
                      isFocused: _isAgeFocused,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Encryption note
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SYSTEM ENCRYPTION ACTIVE // END-TO-END SECURE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black.withValues(alpha: 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      Navigator.pushNamed(context, '/goals');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'DATA_PKT_SENT_V1.0.4',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
