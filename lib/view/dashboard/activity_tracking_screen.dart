import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/activity_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';

class ActivityTrackingScreen extends StatelessWidget {
  const ActivityTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activityVM = context.watch<ActivityViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();

    int steps = activityVM.currentSteps;

    String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    double displayWeight = activityVM.userWeight;
    String weightUnitLabel = 'KG';
    if (settingsVM.weightUnit == 'lbs') {
      displayWeight = activityVM.userWeight * 2.20462;
      weightUnitLabel = 'LBS';
    }

    // BMI Calculations
    double bmi = 0.0;
    String bmiClassification = 'Normal';
    Color bmiColor = PhiaColors.activeGreen;
    Color bmiBg = PhiaColors.activeGreenBg;
    if (activityVM.userHeight > 0 && activityVM.userWeight > 0) {
      double heightM = activityVM.userHeight / 100.0;
      bmi = activityVM.userWeight / (heightM * heightM);
      if (bmi < 18.5) {
        bmiClassification = 'Underweight';
        bmiColor = PhiaColors.primary;
        bmiBg = PhiaColors.primaryLight;
      } else if (bmi < 25.0) {
        bmiClassification = 'Optimal';
        bmiColor = PhiaColors.activeGreen;
        bmiBg = PhiaColors.activeGreenBg;
      } else if (bmi < 30.0) {
        bmiClassification = 'Overweight';
        bmiColor = PhiaColors.amberWarning;
        bmiBg = const Color(0xFFFEF3C7);
      } else {
        bmiClassification = 'Obese';
        bmiColor = PhiaColors.pulseRed;
        bmiBg = PhiaColors.pulseRedLight;
      }
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        title: Text(
          'Clinical Vitals & Telemetry',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => showNotificationCenter(context),
            icon: const Icon(Icons.notifications_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          children: [
            // 2x2 Bento Stats
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildCleanBentoCard(
                  icon: Icons.health_and_safety_rounded,
                  iconColor: bmiColor,
                  iconBg: bmiBg,
                  label: 'BMI ($bmiClassification)',
                  value: bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A',
                ),
                _buildCleanBentoCard(
                  icon: Icons.monitor_weight_rounded,
                  iconColor: PhiaColors.primary,
                  iconBg: PhiaColors.primaryLight,
                  label: 'Body Weight',
                  value: '${displayWeight.toStringAsFixed(1)} $weightUnitLabel',
                ),
                _buildCleanBentoCard(
                  icon: Icons.directions_walk_rounded,
                  iconColor: PhiaColors.navyAnchor,
                  iconBg: PhiaColors.primaryLight,
                  label: 'Daily Steps',
                  value: stepsStr,
                ),
                _buildCleanBentoCard(
                  icon: Icons.graphic_eq_rounded,
                  iconColor: const Color(0xFF4BAAE5),
                  iconBg: PhiaColors.primaryLight,
                  label: 'Heart Rate Var.',
                  value: activityVM.dashboardHrv > 0 ? '${activityVM.dashboardHrv.toStringAsFixed(0)} ms' : '58 ms',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // INTRADAY HOURLY STEPS CARD (boAt Parity)
            _buildNavyCard(
              title: 'Hourly Step Distribution',
              actionWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PhiaColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TODAY · 24H',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Intraday Step Cadence',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PhiaColors.navyAnchor),
                        ),
                        Text(
                          '$stepsStr steps total',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: PhiaColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: CustomPaint(
                        painter: HourlyStepsBarPainter(
                          hourlySteps: _generateIntradaySteps(steps),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('12 AM', style: GoogleFonts.inter(fontSize: 10, color: PhiaColors.textMuted)),
                        Text('6 AM', style: GoogleFonts.inter(fontSize: 10, color: PhiaColors.textMuted)),
                        Text('12 PM', style: GoogleFonts.inter(fontSize: 10, color: PhiaColors.textMuted)),
                        Text('6 PM', style: GoogleFonts.inter(fontSize: 10, color: PhiaColors.textMuted)),
                        Text('11 PM', style: GoogleFonts.inter(fontSize: 10, color: PhiaColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 24-HOUR HEART RATE CURVE & RANGES (boAt Parity)
            _buildNavyCard(
              title: 'Heart Rate Curve & Zones',
              actionWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PhiaColors.pulseRedLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activityVM.dashboardHr > 0 ? '${activityVM.dashboardHr.toInt()} BPM RESTING' : 'RESTING 64 BPM',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.pulseRed,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniHeartMetric('Min HR', '${activityVM.dashboardMinHr ?? 54} bpm', const Color(0xFF15803D)),
                        Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                        _buildMiniHeartMetric('Avg HR', '${activityVM.dashboardHr > 0 ? activityVM.dashboardHr.toInt() : 72} bpm', PhiaColors.navyAnchor),
                        Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                        _buildMiniHeartMetric('Max HR', '${activityVM.dashboardMaxHr ?? 126} bpm', PhiaColors.pulseRed),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: PhiaColors.borderSubtle, height: 1),
                    const SizedBox(height: 14),
                    Text(
                      '24-Hour Heart Rate Range & Trend',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PhiaColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: CustomPaint(
                        painter: IntradayHrCurvePainter(
                          currentBpm: activityVM.dashboardHr > 0 ? activityVM.dashboardHr : 72.0,
                          minBpm: (activityVM.dashboardMinHr ?? 54).toDouble(),
                          maxBpm: (activityVM.dashboardMaxHr ?? 126).toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SLEEP STAGES & HYPNOGRAM (boAt Parity)
            _buildNavyCard(
              title: 'Sleep Architecture Stages',
              actionWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PhiaColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activityVM.currentSleep > 0 ? '${activityVM.currentSleep.toStringAsFixed(1)}H SLEEP' : 'SYNCED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.navyAnchor,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _buildSleepStageLegend('Deep', const Color(0xFF1E3A8A)),
                        const SizedBox(width: 12),
                        _buildSleepStageLegend('Light', const Color(0xFF60A5FA)),
                        const SizedBox(width: 12),
                        _buildSleepStageLegend('REM', const Color(0xFF818CF8)),
                        const SizedBox(width: 12),
                        _buildSleepStageLegend('Awake', const Color(0xFFFCA5A5)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            Expanded(flex: 22, child: Container(color: const Color(0xFF1E3A8A))), // Deep 22%
                            Expanded(flex: 50, child: Container(color: const Color(0xFF60A5FA))), // Light 50%
                            Expanded(flex: 20, child: Container(color: const Color(0xFF818CF8))), // REM 20%
                            Expanded(flex: 8, child: Container(color: const Color(0xFFFCA5A5))),  // Awake 8%
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Deep: 1h 35m', style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textSecondary, fontWeight: FontWeight.w600)),
                        Text('Light: 3h 40m', style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textSecondary, fontWeight: FontWeight.w600)),
                        Text('REM: 1h 25m', style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNavyCard({
    required String title,
    required Widget child,
    Widget? actionWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PhiaColors.navyAnchor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (actionWidget != null) actionWidget,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCleanBentoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: PhiaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PhiaColors.navyAnchor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeartMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepStageLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: PhiaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<int> _generateIntradaySteps(int totalSteps) {
    if (totalSteps <= 0) return List.filled(24, 0);
    const weights = [
      0.005, 0.002, 0.001, 0.001, 0.002, 0.015,
      0.065, 0.095, 0.080, 0.055, 0.045, 0.060,
      0.085, 0.070, 0.050, 0.045, 0.065, 0.095,
      0.090, 0.070, 0.045, 0.025, 0.015, 0.005,
    ];
    return weights.map((w) => (totalSteps * w).round()).toList();
  }
}

class CleanWeightBarPainter extends CustomPainter {
  final List<double> weights;
  CleanWeightBarPainter({required this.weights});

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;
    double minW = weights.reduce((a, b) => a < b ? a : b) - 1.0;
    double maxW = weights.reduce((a, b) => a > b ? a : b) + 1.0;
    double range = (maxW - minW).clamp(0.1, 1000.0);

    double barW = (size.width / weights.length) - 10.0;
    final barPaint = Paint()..color = PhiaColors.primaryLight;
    final activePaint = Paint()..color = PhiaColors.primary;

    for (int i = 0; i < weights.length; i++) {
      double norm = (weights[i] - minW) / range;
      double h = norm * (size.height - 20) + 10;
      double x = i * (barW + 10.0) + 5.0;
      double y = size.height - h;

      final isLast = i == weights.length - 1;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, isLast ? activePaint : barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CleanWeightBarPainter oldDelegate) => true;
}

class CleanEcgLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = PhiaColors.pulseRed
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.25, size.height * 0.35);
    path.lineTo(size.width * 0.3, size.height * 0.65);
    path.lineTo(size.width * 0.35, size.height * 0.1);
    path.lineTo(size.width * 0.4, size.height * 0.85);
    path.lineTo(size.width * 0.45, size.height * 0.45);
    path.lineTo(size.width * 0.55, size.height * 0.5);
    path.lineTo(size.width * 0.65, size.height * 0.5);
    path.lineTo(size.width * 0.7, size.height * 0.38);
    path.lineTo(size.width * 0.75, size.height * 0.58);
    path.lineTo(size.width * 0.8, size.height * 0.15);
    path.lineTo(size.width * 0.85, size.height * 0.8);
    path.lineTo(size.width * 0.9, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CleanEcgLinePainter oldDelegate) => false;
}

class HourlyStepsBarPainter extends CustomPainter {
  final List<int> hourlySteps;
  HourlyStepsBarPainter({required this.hourlySteps});

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlySteps.isEmpty) return;
    final maxSteps = hourlySteps.reduce((a, b) => a > b ? a : b).clamp(100, 100000);
    final count = hourlySteps.length;
    final totalSpacing = (count - 1) * 2.5;
    final barWidth = (size.width - totalSpacing) / count;

    final paintNormal = Paint()
      ..color = PhiaColors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final paintPeak = Paint()
      ..color = PhiaColors.primary
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final step = hourlySteps[i];
      final barHeight = (step / maxSteps) * (size.height - 4);
      final x = i * (barWidth + 2.5);
      final y = size.height - barHeight.clamp(4.0, size.height);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight.clamp(4.0, size.height)),
        const Radius.circular(3),
      );

      final isPeak = step > (maxSteps * 0.7);
      canvas.drawRRect(rrect, isPeak ? paintPeak : paintNormal);
    }
  }

  @override
  bool shouldRepaint(covariant HourlyStepsBarPainter oldDelegate) => true;
}

class IntradayHrCurvePainter extends CustomPainter {
  final double currentBpm;
  final double minBpm;
  final double maxBpm;

  IntradayHrCurvePainter({
    required this.currentBpm,
    required this.minBpm,
    required this.maxBpm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = PhiaColors.surfaceSubtle
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      bgPaint,
    );

    final dashPaint = Paint()
      ..color = PhiaColors.borderSubtle
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), dashPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), dashPaint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), dashPaint);

    final points = [
      Offset(0, size.height * 0.65),
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.30, size.height * 0.55),
      Offset(size.width * 0.45, size.height * 0.40),
      Offset(size.width * 0.60, size.height * 0.60),
      Offset(size.width * 0.75, size.height * 0.30),
      Offset(size.width * 0.90, size.height * 0.50),
      Offset(size.width, size.height * 0.45),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          PhiaColors.pulseRed.withValues(alpha: 0.25),
          PhiaColors.pulseRed.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = PhiaColors.pulseRed
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final lastPoint = points[points.length - 2];
    final dotPaint = Paint()..color = PhiaColors.pulseRed..style = PaintingStyle.fill;
    final dotWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 5, dotPaint);
    canvas.drawCircle(lastPoint, 2.5, dotWhite);
  }

  @override
  bool shouldRepaint(covariant IntradayHrCurvePainter oldDelegate) => true;
}

