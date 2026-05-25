import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class LiveWorkoutScreen extends StatefulWidget {
  const LiveWorkoutScreen({super.key});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> with SingleTickerProviderStateMixin {
  // Timer & dynamic variables
  Timer? _workoutTimer;
  Timer? _vitalsTimer;
  int _secondsElapsed = 1485; // 24 minutes and 45 seconds (24 * 60 + 45 = 1485)
  int _heartRate = 164;
  int _calories = 428;
  bool _isPaused = false;

  // Heartbeat pulse animation
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  // Waveform animation offsets for subtle live visual movement
  final Random _random = Random();
  final List<double> _waveformFactors = List.filled(11, 1.0);

  @override
  void initState() {
    super.initState();

    // Heartbeat pulsing controller
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    // Dynamic ticking stopwatch timer
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    // Slight vital fluctuations + wave bar perturbations to make the screen feel "ALIVE"
    _vitalsTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          // Heart rate fluctuates around 164 BPM (160 to 168)
          _heartRate = 160 + _random.nextInt(9);
          // Calories increase very slowly
          if (_random.nextDouble() > 0.7) {
            _calories++;
          }
          // Dynamic wave bar height factors perturb slightly
          for (int i = 0; i < _waveformFactors.length; i++) {
            _waveformFactors[i] = 0.85 + _random.nextDouble() * 0.3;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _vitalsTimer?.cancel();
    _heartController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    String minStr = minutes < 10 ? '0$minutes' : '$minutes';
    String secStr = seconds < 10 ? '0$seconds' : '$seconds';
    return '$minStr:$secStr';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _heartController.stop();
      } else {
        _heartController.repeat(reverse: true);
      }
    });
  }

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
                // 1. HEADER ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                      // HIIT Session Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161818),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'HIIT SESSION',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. STOPWATCH TIMER
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL TIME',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(_secondsElapsed),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 76,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. VITALS DUAL GRID (KCAL & BPM)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    children: [
                      // KCAL column
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_calories',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'KCAL',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Vertical Divider
                      Container(
                        height: 28,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      // BPM column
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_heartRate',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 32,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ScaleTransition(
                                  scale: _heartScale,
                                  child: const Icon(
                                    Icons.favorite,
                                    color: PhiaColors.pulseRed,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'BPM',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 4. MAIN INTERACTIVE CONTENT AREA (SCROLLABLE BENTO BOXES)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      // A. INTENSITY BENTO CARD (Anaerobic wave visualizer)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'INTENSITY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'ANAEROBIC',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Waveform bars row
                            SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(11, (index) {
                                  // Base curved height
                                  final double baseHeight = [18.0, 24.0, 32.0, 42.0, 48.0, 54.0, 46.0, 38.0, 28.0, 22.0, 16.0][index];
                                  // Add live pulsation factor
                                  final double barHeight = baseHeight * _waveformFactors[index];
                                  final bool isPeak = index == 5;

                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: isPeak 
                                            ? Colors.white 
                                            : Colors.white.withValues(alpha: 0.12 + (index <= 5 ? index : 10 - index) * 0.08),
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // B. CURRENT EXERCISE CARD (Pushups tracker card)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PUSH-UPS',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 28,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '15',
                                            style: GoogleFonts.bebasNeue(
                                              fontSize: 54,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'REPS',
                                            style: GoogleFonts.bebasNeue(
                                              fontSize: 18,
                                              color: Colors.white.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Push-up grayscale photo
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    image: const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=500'),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0.2126, 0.7152, 0.0722, 0, -20,
                                        0,      0,      0,      1, 0,
                                      ]),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Set and Intensity indicators with 60% progress line
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'SET 3 OF 4',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Text(
                                      '85% INTENSITY',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    Container(
                                      height: 2,
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: 0.6, // 60% progress
                                      child: Container(
                                        height: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // C. UP NEXT CAPSULE CARD
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.timer_outlined,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UP NEXT',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'PLANK',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 16,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '30S',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // 5. TACTICAL ACTION CAPSULES ROW (PAUSE & END WORKOUT)
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _togglePause,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                            backgroundColor: _isPaused ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                          ),
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            _isPaused ? 'RESUME' : 'PAUSE',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.stop, color: Colors.black, size: 16),
                          label: Text(
                            'END WORKOUT',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 16,
                              color: Colors.black,
                              letterSpacing: 1.0,
                            ),
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
}
