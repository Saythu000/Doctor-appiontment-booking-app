import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/health_viewmodel.dart';

class PulseScanScreen extends StatelessWidget {
  const PulseScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthVM = context.watch<HealthViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix Grid Background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Area
                  Text(
                    'PPG PULSE SCANNER',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 32,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    'Direct heart rate and HRV hardware polling',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Circular Finger Placement Zone / Status View
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        border: Border.all(
                          color: healthVM.isPpgScanning 
                              ? (healthVM.fingerDetected ? PhiaColors.stepGreen.withValues(alpha: 0.3) : PhiaColors.pulseRed.withValues(alpha: 0.3)) 
                              : Colors.white.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!healthVM.isPpgScanning) ...[
                            // Idle instruction screen
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 2.0),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.fingerprint, size: 40, color: Colors.white38),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'READY TO MEASURE',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 20,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    'Cover the back camera lens and flash entirely with your index finger for the most accurate readings.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white54,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (!healthVM.fingerDetected) ...[
                            // Finger not detected overlay
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: PhiaColors.pulseRed.withValues(alpha: 0.1),
                                    border: Border.all(color: PhiaColors.pulseRed, width: 2.0),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.warning_amber_rounded, size: 44, color: PhiaColors.pulseRed),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'ALIGN YOUR FINGER',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 20,
                                    color: PhiaColors.pulseRed,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    'Luminance values are too low. Gently press your finger against the camera lens and flash so that it is saturated in red.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white60,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Live Scanning - show ECG Wave Graph
                            Positioned.fill(
                              child: CustomPaint(
                                painter: RealTimeECGWavePainter(
                                  points: healthVM.wavePoints,
                                  accentColor: PhiaColors.pulseRed,
                                ),
                              ),
                            ),
                            
                            // Pulse dot indicator
                            Positioned(
                              top: 24,
                              right: 24,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: PhiaColors.pulseRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PULSE DETECTED',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white60,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Real-time metrics readouts in Bento layout
                  Row(
                    children: [
                      // BPM Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: PhiaColors.surface,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HEART RATE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    healthVM.liveBpm > 0 ? healthVM.liveBpm.toStringAsFixed(0) : '--',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 48,
                                      color: healthVM.fingerDetected ? PhiaColors.pulseRed : Colors.white24,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BPM',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // HRV Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: PhiaColors.surface,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HRV (RMSSD)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    healthVM.liveHrv > 0 ? healthVM.liveHrv.toStringAsFixed(0) : '--',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 48,
                                      color: healthVM.fingerDetected ? PhiaColors.skyBlue : Colors.white24,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MS',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white38,
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
                  const SizedBox(height: 24),

                  // Large Retro Action Button
                  GestureDetector(
                    onTap: healthVM.isPpgScanning ? healthVM.stopPpgScan : healthVM.startPpgScan,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: healthVM.isPpgScanning ? Colors.white : Colors.transparent,
                        border: Border.all(
                          color: healthVM.isPpgScanning ? Colors.white : Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          healthVM.isPpgScanning ? 'STOP PULSE SCAN' : 'START PULSE SCAN',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            color: healthVM.isPpgScanning ? Colors.black : Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
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

// Custom Painter to draw real-time scrolling blood flow volume pulse waves (ECG lines)
class RealTimeECGWavePainter extends CustomPainter {
  final List<double> points;
  final Color accentColor;

  RealTimeECGWavePainter({required this.points, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double spacing = size.width / (points.length > 1 ? points.length - 1 : 1);
    
    for (int i = 0; i < points.length; i++) {
      double x = i * spacing;
      double signalVal = points[i];
      double y = (size.height / 2) - (signalVal * 8.0);
      y = y.clamp(10.0, size.height - 10.0);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RealTimeECGWavePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
