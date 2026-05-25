import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class ActivityTrackingScreen extends StatelessWidget {
  const ActivityTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                // Top Header (◎ KINETIC and Notification Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.radio_button_checked, color: Colors.white, size: 20),
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
                        'ACTIVITY OVERVIEW',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LAST 30 DAYS PERFORMANCE',
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
                            icon: Icons.timer_outlined,
                            value: '42.5H',
                            label: 'TOTAL TIME',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.local_fire_department_outlined,
                            value: '18,240',
                            label: 'KCAL BURNED',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.fitness_center_outlined,
                            value: '24',
                            label: 'WORKOUTS',
                          ),
                          _buildStatBentoCard(
                            icon: Icons.speed_outlined,
                            value: '72%',
                            label: 'INTENSITY',
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
                                  'WEIGHT TRACKING (KG)',
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
                                    '-2.4kg this month',
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
                                  weights: const [79.8, 79.5, 80.2, 79.1, 78.8, 78.5, 78.2, 77.4],
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
                            Text(
                              'AVG HEART RATE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '142',
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

                      const SizedBox(height: 20),

                      // Streak Status Card
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Stack(
                          children: [
                            // Grayscale Cover Image
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: PhiaColors.surface,
                                  image: DecorationImage(
                                    image: NetworkImage('https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=600'),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.matrix(<double>[
                                      0.2126, 0.7152, 0.0722, 0, -35,
                                      0.2126, 0.7152, 0.0722, 0, -35,
                                      0.2126, 0.7152, 0.0722, 0, -35,
                                      0,      0,      0,      1, 0,
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                            // Black gradient mask for high typography readability
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // Details overlay
                            Positioned(
                              left: 20,
                              bottom: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STREAK STATUS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '7 DAYS STRONG',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 26,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'KEEP PUSHING TO HIT 14!',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // RECENT ACHIEVEMENTS Section Title
                      Text(
                        'RECENT ACHIEVEMENTS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Achievements list bento panel
                      _buildAchievementCard(
                        icon: Icons.directions_walk_outlined,
                        title: '10K STEPS BADGE',
                        date: 'Unlocked May 12, 2024',
                        isCompleted: true,
                      ),
                      const SizedBox(height: 12),
                      _buildAchievementCard(
                        icon: Icons.gps_fixed_outlined,
                        title: '7-DAY STREAK',
                        date: 'Personal Best Milestone',
                        isCompleted: false,
                      ),
                      const SizedBox(height: 12),
                      _buildAchievementCard(
                        icon: Icons.star_border_outlined,
                        title: 'ENDURANCE MASTER',
                        date: 'Completed 60min HIIT session',
                        isCompleted: true,
                        customNumberIcon: '10',
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

  // Achievements list row card builder
  Widget _buildAchievementCard({
    required IconData icon,
    required String title,
    required String date,
    required bool isCompleted,
    String? customNumberIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Left Circle Icon frame
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Center(
              child: customNumberIcon != null
                  ? Text(
                      customNumberIcon,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Center Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          // Right checkbox / checkmark circle status
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.white : Colors.transparent,
              border: Border.all(
                color: isCompleted ? Colors.white : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: isCompleted
                ? const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 12,
                    ),
                  )
                : null,
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
    final double maxVal = 82.0;
    final double minVal = 76.0;
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
