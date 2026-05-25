import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/health_viewmodel.dart';

class GPSWorkoutScreen extends StatelessWidget {
  const GPSWorkoutScreen({super.key});

  String _formatDuration(int totalSecs) {
    int hrs = totalSecs ~/ 3600;
    int mins = (totalSecs % 3600) ~/ 60;
    int secs = totalSecs % 60;

    String hrsStr = hrs.toString().padLeft(2, '0');
    String minsStr = mins.toString().padLeft(2, '0');
    String secsStr = secs.toString().padLeft(2, '0');

    return '$hrsStr:$minsStr:$secsStr';
  }

  String _getPaceString(double speedKmh) {
    if (speedKmh <= 0.5) return "--:--";
    double paceDecimal = 60.0 / speedKmh;
    int minutes = paceDecimal.toInt();
    int seconds = ((paceDecimal - minutes) * 60).toInt();
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final healthVM = context.watch<HealthViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix Grid Background overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS WORKOUT TRACKER',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            Text(
                              'Offline coordinate speed and distance mapping',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pushNamed(context, '/workout_library'),
                        icon: const Icon(Icons.fitness_center_outlined, color: Colors.white),
                        tooltip: 'Workout Library',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Large Stopwatch Display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: PhiaColors.surface,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ELAPSED TIME',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(healthVM.elapsedSeconds),
                          style: GoogleFonts.bebasNeue(
                            fontSize: 64,
                            color: healthVM.isGpsTracking && !healthVM.isGpsPaused ? PhiaColors.stepGreen : Colors.white24,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Route Canvas/Breadcrumb Trail Map
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        border: Border.all(
                          color: healthVM.isGpsTracking && !healthVM.isGpsPaused 
                              ? PhiaColors.stepGreen.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (healthVM.routeCoordinates.isEmpty) ...[
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.map_outlined, color: Colors.white24, size: 40),
                                  const SizedBox(height: 16),
                                  Text(
                                    'ROUTE MAP INACTIVE',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 16,
                                      color: Colors.white38,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Live breadcrumb trail starts with session',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Live Breadcrumb map
                            Positioned.fill(
                              child: CustomPaint(
                                painter: GPSRoutePathPainter(
                                  coordinates: healthVM.routeCoordinates,
                                  lineColor: PhiaColors.stepGreen,
                                ),
                              ),
                            ),
                            
                            // Accuracy/GPS Indicator dot
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: healthVM.gpsAccuracy < 10 ? PhiaColors.stepGreen : PhiaColors.warningOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GPS ACCURACY: ${healthVM.gpsAccuracy.toStringAsFixed(1)}M',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
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

                  // Bento Metrics Grid
                  Row(
                    children: [
                      // Distance Card
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
                                'DISTANCE',
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
                                    healthVM.totalDistanceKm.toStringAsFixed(2),
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'KM',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: PhiaColors.stepGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Pace Card
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
                                'LIVE PACE',
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
                                    _getPaceString(healthVM.currentSpeedKmh),
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/KM',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: PhiaColors.warningOrange,
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

                  // Session Control Actions
                  if (!healthVM.isGpsTracking) ...[
                    GestureDetector(
                      onTap: healthVM.startGpsWorkout,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            'START WORKOUT SESSION',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 18,
                              color: Colors.black,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        // Pause / Resume Action
                        Expanded(
                          child: GestureDetector(
                            onTap: healthVM.toggleGpsPause,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: healthVM.isGpsPaused ? PhiaColors.stepGreen : Colors.transparent,
                                border: Border.all(
                                  color: healthVM.isGpsPaused ? PhiaColors.stepGreen : Colors.white38,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  healthVM.isGpsPaused ? 'RESUME RUN' : 'PAUSE RUN',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 18,
                                    color: healthVM.isGpsPaused ? Colors.black : Colors.white,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Stop & Finish Action
                        Expanded(
                          child: GestureDetector(
                            onTap: healthVM.stopGpsWorkout,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: PhiaColors.pulseRed,
                                border: Border.all(color: PhiaColors.pulseRed, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  'STOP & SAVE',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 18,
                                    color: Colors.black,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw a clean grid background and a continuous glowing route trail
class GPSRoutePathPainter extends CustomPainter {
  final List<Position> coordinates;
  final Color lineColor;

  GPSRoutePathPainter({required this.coordinates, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double pad = 40.0;
    
    // Draw minimalist Nothing OS coordinate crosshairs grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    int hLines = 6;
    for (int i = 0; i <= hLines; i++) {
      double y = (size.height / hLines) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Draw vertical grid lines
    int vLines = 6;
    for (int i = 0; i <= vLines; i++) {
      double x = (size.width / vLines) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (coordinates.isEmpty) return;

    // Calculate boundaries of route coordinates to center/scale them on the canvas
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (var pos in coordinates) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    double dLat = maxLat - minLat;
    double dLng = maxLng - minLng;

    dLat = dLat == 0.0 ? 0.00001 : dLat;
    dLng = dLng == 0.0 ? 0.00001 : dLng;

    double widthScale = (size.width - 2 * pad) / dLng;
    double heightScale = (size.height - 2 * pad) / dLat;
    double scale = widthScale < heightScale ? widthScale : heightScale;

    final routePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (int i = 0; i < coordinates.length; i++) {
      var pos = coordinates[i];
      double x = pad + (pos.longitude - minLng) * scale;
      double y = size.height - (pad + (pos.latitude - minLat) * scale);

      if (i == 0) {
        path.moveTo(x, y);
        final startDotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 5.0, startDotPaint);
      } else {
        path.lineTo(x, y);
      }
      
      if (i == coordinates.length - 1) {
        final endDotPaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 6.0, endDotPaint);
      }
    }

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant GPSRoutePathPainter oldDelegate) {
    return oldDelegate.coordinates != coordinates;
  }
}
