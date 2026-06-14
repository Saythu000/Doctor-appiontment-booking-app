import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/activity_viewmodel.dart';

import '../../viewmodel/settings_viewmodel.dart';

class ActivityTrackingScreen extends StatelessWidget {
  const ActivityTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activityVM = context.watch<ActivityViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();

    // Dynamic metrics calculation
    int activeMins = activityVM.currentActiveMins;
    int calories = activityVM.currentCalories;
    int steps = activityVM.currentSteps;

    String totalTimeStr = activeMins > 60 
        ? '${(activeMins / 60.0).toStringAsFixed(1)}H' 
        : '$activeMins MIN';

    String caloriesStr = calories.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Dynamic units conversion
    double displayWeight = activityVM.userWeight;
    String weightUnitLabel = 'KG';
    if (settingsVM.weightUnit == 'lbs') {
      displayWeight = activityVM.userWeight * 2.20462;
      weightUnitLabel = 'LBS';
    }

    double displayHeight = activityVM.userHeight;
    String heightUnitLabel = 'CM';
    if (settingsVM.heightUnit == 'in.') {
      displayHeight = activityVM.userHeight * 0.393701;
      heightUnitLabel = 'IN';
    }

    // BMI Calculations
    double bmi = 0.0;
    String bmiClassification = 'N/A';
    if (activityVM.userHeight > 0 && activityVM.userWeight > 0) {
      double heightM = activityVM.userHeight / 100.0;
      bmi = activityVM.userWeight / (heightM * heightM);
      if (bmi < 18.5) {
        bmiClassification = 'UNDERWEIGHT';
      } else if (bmi < 25.0) {
        bmiClassification = 'NORMAL';
      } else if (bmi < 30.0) {
        bmiClassification = 'OVERWEIGHT';
      } else {
        bmiClassification = 'OBESE';
      }
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix Background Grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (◎ DRGODLY and Notification Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_hospital, color: Colors.white, size: 20),
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
                      IconButton(
                        onPressed: () => showNotificationCenter(context),
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 8),
                      // Title block
                      Text(
                        'CLINICAL TELEMETRY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PATIENT VITALS & STATS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.38),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2x2 Grid of Bento Stats Cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.25,
                        children: [
                          _buildStatBentoCard(
                            icon: Icons.health_and_safety_outlined,
                            value: bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A',
                            label: 'BMI ($bmiClassification)',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.monitor_weight_outlined,
                            value: '${displayWeight.toStringAsFixed(0)} $weightUnitLabel / ${displayHeight.toStringAsFixed(0)} $heightUnitLabel',
                            label: 'WEIGHT / HEIGHT',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.directions_walk_outlined,
                            value: stepsStr,
                            label: 'DAILY MOBILITY',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.favorite_border_outlined,
                            value: activityVM.dashboardHrv > 0 ? '${activityVM.dashboardHrv.toStringAsFixed(0)} MS' : '55 MS',
                            label: 'HR VARIABILITY',
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Weight Tracking Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'WEIGHT TRACKING ($weightUnitLabel)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  child: Text(
                                    settingsVM.weightUnit == 'lbs' ? '-5.3lbs this month' : '-2.4kg this month',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Weight Column Chart Canvas
                            SizedBox(
                              height: 120,
                              child: CustomPaint(
                                painter: WeightTrackingBarPainter(
                                  weights: [
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 5.3 : 2.4),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 4.6 : 2.1),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 4.0 : 1.8),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 3.3 : 1.5),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 2.6 : 1.2),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 2.0 : 0.9),
                                    displayWeight + (settingsVM.weightUnit == 'lbs' ? 1.1 : 0.5),
                                    displayWeight,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Avg Heart Rate Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PULSE & ECG TELEMETRY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    'STATUS: SINUS RHYTHM',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: PhiaColors.stepGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  activityVM.dashboardHr > 0 
                                      ? activityVM.dashboardHr.toStringAsFixed(0) 
                                      : '72',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'BPM',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Custom Wavy Dotted Path Painter
                            SizedBox(
                              height: 50,
                              child: CustomPaint(
                                painter: DottedPulseWavePainter(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
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

  // Bento grid card builder
  Widget _buildStatBentoCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.bebasNeue(
                  fontSize: 26,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// Custom Painter representing an 8-column Weight tracking grid
// All columns are dark gray, peaking with the last bar in solid white!
class WeightTrackingBarPainter extends CustomPainter {
  final List<double> weights;

  WeightTrackingBarPainter({required this.weights});

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;
    final double minVal = weights.reduce(min) - 1.0;
    final double maxVal = weights.reduce(max) + 1.0;
    final double chartHeight = size.height;
    final double chartWidth = size.width;

    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final barTopOutlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final activeBarPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Calculate columns parameters
    double totalSpacingRatio = 0.3;
    double barWidth = (chartWidth / weights.length) * (1.0 - totalSpacingRatio);
    double spacing = (chartWidth / weights.length) * totalSpacingRatio;

    for (int i = 0; i < weights.length; i++) {
      double x = i * (barWidth + spacing) + (spacing / 2);
      double val = weights[i];
      
      // Calculate normalized height scale
      double pct = ((val - minVal) / (maxVal - minVal)).clamp(0.15, 1.0);
      double barHeight = pct * chartHeight;
      double y = chartHeight - barHeight;

      bool isLast = i == weights.length - 1;

      if (isLast) {
        // Active bar is solid white
        canvas.drawRect(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          activeBarPaint,
        );
      } else {
        // Historical bar is dark gray
        canvas.drawRect(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          barPaint,
        );
        // Thin white top border outline
        canvas.drawLine(
          Offset(x, y),
          Offset(x + barWidth, y),
          barTopOutlinePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightTrackingBarPainter oldDelegate) {
    return oldDelegate.weights != weights;
  }
}

// Custom Painter drawing a sleek dotted pulse wavy path
class DottedPulseWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height;
    final double chartWidth = size.width;

    final dotPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;

    // We will draw the four independent curved pulse segments using bezier samplings
    // Segment 1: Rises and curves down
    _drawDottedSegment(
      canvas,
      start: Offset(0, chartHeight * 0.7),
      cp1: Offset(chartWidth * 0.08, chartHeight * 0.6),
      cp2: Offset(chartWidth * 0.16, chartHeight * 0.65),
      end: Offset(chartWidth * 0.25, chartHeight * 0.95),
      dotPaint: dotPaint,
    );

    // Segment 2: Rises high
    _drawDottedSegment(
      canvas,
      start: Offset(chartWidth * 0.32, chartHeight * 0.95),
      cp1: Offset(chartWidth * 0.38, chartHeight * 0.7),
      cp2: Offset(chartWidth * 0.44, chartHeight * 0.45),
      end: Offset(chartWidth * 0.5, chartHeight * 0.35),
      dotPaint: dotPaint,
    );

    // Segment 3: Starts high and curves down
    _drawDottedSegment(
      canvas,
      start: Offset(chartWidth * 0.58, chartHeight * 0.35),
      cp1: Offset(chartWidth * 0.62, chartHeight * 0.5),
      cp2: Offset(chartWidth * 0.66, chartHeight * 0.75),
      end: Offset(chartWidth * 0.72, chartHeight * 0.95),
      dotPaint: dotPaint,
    );

    // Segment 4: Starts low and curves up
    _drawDottedSegment(
      canvas,
      start: Offset(chartWidth * 0.82, chartHeight * 0.95),
      cp1: Offset(chartWidth * 0.86, chartHeight * 0.75),
      cp2: Offset(chartWidth * 0.92, chartHeight * 0.55),
      end: Offset(chartWidth * 0.98, chartHeight * 0.4),
      dotPaint: dotPaint,
    );
  }

  // Draw dotted bezier segment using mathematical cubic evaluation
  void _drawDottedSegment(
    Canvas canvas, {
    required Offset start,
    required Offset cp1,
    required Offset cp2,
    required Offset end,
    required Paint dotPaint,
  }) {
    int segmentsCount = 20;
    for (int i = 0; i <= segmentsCount; i++) {
      double t = i / segmentsCount;
      
      // Standard cubic bezier equation
      double x = pow(1 - t, 3) * start.dx +
          3 * pow(1 - t, 2) * t * cp1.dx +
          3 * (1 - t) * pow(t, 2) * cp2.dx +
          pow(t, 3) * end.dx;
      
      double y = pow(1 - t, 3) * start.dy +
          3 * pow(1 - t, 2) * t * cp1.dy +
          3 * (1 - t) * pow(t, 2) * cp2.dy +
          pow(t, 3) * end.dy;

      canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DottedPulseWavePainter oldDelegate) => false;
}
