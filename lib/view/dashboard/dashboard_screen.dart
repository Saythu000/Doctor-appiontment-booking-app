import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/health_viewmodel.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int)? onTabSelected;
  const DashboardScreen({super.key, this.onTabSelected});

  Widget _buildVitalCapsule(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 14,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthVM = context.watch<HealthViewModel>();

    // Dynamic metrics calculation
    int steps = healthVM.liveSteps > 0 ? healthVM.liveSteps : (healthVM.dashboardSteps > 0 ? healthVM.dashboardSteps : 8432);
    int calories = healthVM.dashboardActiveTimeMins > 0 ? (healthVM.dashboardActiveTimeMins * 10).toInt() : 420;
    int activeMins = healthVM.dashboardActiveTimeMins > 0 ? healthVM.dashboardActiveTimeMins : 45;

    double progressSteps = (steps / 10000.0).clamp(0.0, 1.0);
    double progressCalories = (calories / 500.0).clamp(0.0, 1.0);
    double progressActiveMins = (activeMins / 60.0).clamp(0.0, 1.0);

    // Steps formatting
    String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Heart rate/Speed formats
    String heartRateStr = healthVM.dashboardHr > 0 ? '${healthVM.dashboardHr.toStringAsFixed(0)} BPM' : '68 BPM';
    String speedStr = healthVM.dashboardDistanceKm > 0 ? '${(healthVM.dashboardDistanceKm / (activeMins / 60.0)).toStringAsFixed(1)} KM/H' : '4.2 KM/H';

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Ambient Dot Matrix Grid Background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 2. Main Scrollable Dashboard Panel
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'KINETIC',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Profile Welcome Greeting & Streak Block
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOOD MORNING, ALEX',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 28,
                              letterSpacing: 2.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your energy levels are peaking today.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      // 14 Streak badge card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1C1C),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '14',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'STREAK',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DAILY ACTIVITY Concentric circular Progress Card
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/activity_tracking'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY ACTIVITY',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                              const Icon(Icons.show_chart, color: Colors.white54, size: 18),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Stacked Concentric progress rings with custom painter
                          Center(
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(140, 140),
                                    painter: ConcentricActivityPainter(
                                      stepsPct: progressSteps,
                                      caloriesPct: progressCalories,
                                      activeMinsPct: progressActiveMins,
                                    ),
                                  ),
                                  Text(
                                    '${((progressSteps + progressCalories + progressActiveMins) / 3 * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bullet details below
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBulletItem('STEPS', stepsStr, Colors.white),
                              const SizedBox(height: 12),
                              _buildBulletItem('CALORIES', '$calories', Colors.white70),
                              const SizedBox(height: 12),
                              _buildBulletItem('ACTIVE MINS', '$activeMins', Colors.white30),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WEEKLY PROGRESS Bar Chart card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: PhiaColors.surface,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'WEEKLY PROGRESS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '3,200 KCAL',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 24,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Weekly Custom bar chart
                        SizedBox(
                          height: 140,
                          child: CustomPaint(
                            size: const Size(double.infinity, 140),
                            painter: WeeklyProgressBarPainter(
                              values: const [400, 520, 460, 680, 850, 200, 180], // Thursday / Friday = 850 / weekend
                              highlightedIndex: 4, // index 4 = Friday "NOW"
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // UP NEXT Workout Card Section
                  Text(
                    'UP NEXT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Video workout banner
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1000',
                        ),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black45,
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Linear bottom gradient
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Tags & description row overlay
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  // Core solid white tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    color: Colors.white,
                                    child: Text(
                                      'CORE',
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Intermediate outline tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white54),
                                    ),
                                    child: Text(
                                      'INTERMEDIATE',
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HIIT CORE - 20 MINS',
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 24,
                                            color: Colors.white,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Focus on explosive stability and rotational power.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Solid white play circle button
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Quick Stats vital Capsules Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildVitalCapsule(Icons.favorite_outline, heartRateStr, PhiaColors.pulseRed),
                        const SizedBox(width: 12),
                        _buildVitalCapsule(Icons.speed_outlined, speedStr, PhiaColors.skyBlue),
                        const SizedBox(width: 12),
                        _buildVitalCapsule(Icons.hotel_outlined, '7H 20M', PhiaColors.warningOrange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 1. Concentric progress painter for three biological arcs (Steps, Calories, Active minutes)
class ConcentricActivityPainter extends CustomPainter {
  final double stepsPct;
  final double caloriesPct;
  final double activeMinsPct;

  ConcentricActivityPainter({
    required this.stepsPct,
    required this.caloriesPct,
    required this.activeMinsPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeW = 6.0;
    final double spacing = 6.0;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Ring 1 (outermost): Steps (Solid White)
    double r1 = size.width / 2 - strokeW / 2;
    _drawRing(canvas, center, r1, strokeW, stepsPct, Colors.white, Colors.white.withValues(alpha: 0.12));

    // Ring 2 (middle): Calories (Gray)
    double r2 = r1 - strokeW - spacing;
    _drawRing(canvas, center, r2, strokeW, caloriesPct, Colors.white70, Colors.white.withValues(alpha: 0.06));

    // Ring 3 (innermost): Active Mins (Dark Gray)
    double r3 = r2 - strokeW - spacing;
    _drawRing(canvas, center, r3, strokeW, activeMinsPct, Colors.white30, Colors.white.withValues(alpha: 0.03));
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double strokeWidth, double pct, Color color, Color bgColor) {
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2, // Start at Top
      pct * 2 * 3.14159265,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ConcentricActivityPainter oldDelegate) {
    return oldDelegate.stepsPct != stepsPct || oldDelegate.caloriesPct != caloriesPct || oldDelegate.activeMinsPct != activeMinsPct;
  }
}

// 2. Weekly Bar Painter column, highlighting Friday as solid white labeled "NOW"
class WeeklyProgressBarPainter extends CustomPainter {
  final List<int> values;
  final int highlightedIndex;

  WeeklyProgressBarPainter({
    required this.values,
    required this.highlightedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double bottomHeight = 20.0;
    final double topHeight = 16.0;
    final double chartHeight = size.height - bottomHeight - topHeight;
    final double barWidth = (size.width / 7) * 0.55;
    final double spacing = (size.width / 7) * 0.45;
    final int maxVal = 1000;

    final List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (int i = 0; i < 7; i++) {
      double x = i * (barWidth + spacing) + (spacing / 2);
      double valPct = (values[i] / maxVal).clamp(0.08, 1.0);
      double barHeight = valPct * chartHeight;
      double y = topHeight + chartHeight - barHeight;

      // Determine bar opacity colors
      Color color = Colors.white.withValues(alpha: 0.25);
      if (i == highlightedIndex) {
        color = Colors.white; // Friday "NOW"
      } else if (i > highlightedIndex) {
        color = Colors.white.withValues(alpha: 0.08); // Future weekend
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Render the bar column
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);

      // Render "NOW" header text above Friday column
      if (i == highlightedIndex) {
        final nowPainter = TextPainter(
          text: const TextSpan(
            text: 'NOW',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        nowPainter.paint(canvas, Offset(x + (barWidth - nowPainter.width) / 2, y - 12));
      }

      // Render the day text at the bottom column
      final dayPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(
            color: i == highlightedIndex ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      dayPainter.paint(
        canvas,
        Offset(x + (barWidth - dayPainter.width) / 2, topHeight + chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyProgressBarPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.highlightedIndex != highlightedIndex;
  }
}
