import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class BookingConfirmedScreen extends StatefulWidget {
  const BookingConfirmedScreen({super.key});

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen>
    with SingleTickerProviderStateMixin {
  // Flicker animation state
  double _titleOpacity = 1.0;
  Timer? _flickerTimer;

  // Scanline sweeper animation state
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  // Static telemetry values
  late final String _confCode;

  @override
  void initState() {
    super.initState();

    // Generate random confirmation number
    _confCode = '#CONF-${(1000 + Random().nextInt(9000))}';

    // Initialize looped 4-second linear scanline animation
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    // Initialize periodic CRT terminal screen-flicker simulator (runs every 100ms)
    _flickerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (Random().nextDouble() > 0.98) {
        setState(() {
          _titleOpacity = 0.4;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _titleOpacity = 1.0;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _flickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve booking details passed from previous ReviewBookingScreen
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String specialistName = args['name'] as String;
    final String date = args['date'] as String; // "OCTOBER 07, 2023"
    final String time = args['time'] as String; // "08:00"

    // Dynamic session type deducer mapped from specialist names
    String sessionType = 'HYPER-ENDURANCE';
    final String nameUpper = specialistName.toUpperCase();
    if (nameUpper.contains('MARCUS')) {
      sessionType = 'HYPER-ENDURANCE';
    } else if (nameUpper.contains('ELENA')) {
      sessionType = 'RECOVERY_CALIBRATION';
    } else if (nameUpper.contains('DAVID')) {
      sessionType = 'METABOLIC_INTEGRATION';
    } else if (nameUpper.contains('SARAH')) {
      sessionType = 'NEURO-MECHANICAL_SYNC';
    }

    // Dynamic date parser to KINETIC confirmation format (e.g. "OCT 07.2023")
    String formattedDate = 'OCT 07.2023';
    try {
      final cleanDate = date.replaceAll(',', '');
      final parts = cleanDate.split(' ');
      if (parts.length >= 3) {
        final String month = parts[0].substring(0, max(0, min(3, parts[0].length))).toUpperCase();
        final String day = parts[1].padLeft(2, '0');
        final String year = parts[2];
        formattedDate = '$month $day.$year';
      }
    } catch (e) {
      // safe fallback
    }

    // Dynamic time formatter (e.g. "08:00" -> "08:00 AM", "13:15" -> "01:15 PM")
    String formattedTime = time;
    if (!time.contains('AM') && !time.contains('PM')) {
      try {
        final hourParts = time.split(':');
        final doubleHour = double.tryParse(hourParts.first) ?? 8.0;
        if (doubleHour >= 12) {
          final int pmHour = doubleHour > 12 ? (doubleHour - 12).toInt() : 12;
          final String mins = hourParts.last;
          formattedTime = '${pmHour.toString().padLeft(2, '0')}:$mins PM';
        } else {
          final int amHour = doubleHour.toInt();
          final String mins = hourParts.last;
          formattedTime = '${amHour.toString().padLeft(2, '0')}:$mins AM';
        }
      } catch (e) {
        // safe fallback
      }
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Ambient Dot Matrix Grid Background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 2. Main Scrollable Panel
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom Header Row (Menu, Centered KINETIC, desaturated Avatar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                      ),
                      Text(
                        'KINETIC',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      // Desaturated circular athlete avatar profile
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
                          image: const DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=100'),
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
                ),

                // Main Content List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 12),

                      // 3. SUCCESS HERO CARD (Square Aspect Ratio)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double boxWidth = constraints.maxWidth;
                          return AspectRatio(
                            aspectRatio: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Looping animated vertical scanline
                                  AnimatedBuilder(
                                    animation: _scanAnimation,
                                    builder: (context, child) {
                                      return Positioned(
                                        top: _scanAnimation.value * boxWidth,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 2.0,
                                          color: Colors.white.withValues(alpha: 0.06),
                                        ),
                                      );
                                    },
                                  ),

                                  // Central Column
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Circular success check tick badge
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.0),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // CRT-flickering "MISSION SCHEDULED" Title
                                      AnimatedOpacity(
                                        duration: const Duration(milliseconds: 50),
                                        opacity: _titleOpacity,
                                        child: Column(
                                          children: [
                                            Text(
                                              'MISSION SCHEDULED',
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 32,
                                                color: Colors.white,
                                                letterSpacing: 2.0,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 1.0,
                                              width: 90,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // 4. BENTO DETAILS CARD ("SYSTEM OUTPUT: DETAILS_01")
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card Top banner overlay
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'SYSTEM OUTPUT: DETAILS_01',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            // Segmented details rows
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // TYPE row
                                  _buildDetailRow('TYPE', sessionType.toUpperCase(), isBebas: true),
                                  const SizedBox(height: 16),

                                  // OPERATIVE row
                                  _buildDetailRow('OPERATIVE', specialistName.toUpperCase(), isBebas: false),
                                  const SizedBox(height: 20),

                                  // DATE & TIME Split Grid
                                  Row(
                                    children: [
                                      // Date segment (Left)
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                width: 1.0,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'DATE',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white.withValues(alpha: 0.4),
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                formattedDate,
                                                style: GoogleFonts.bebasNeue(
                                                  fontSize: 22,
                                                  color: Colors.white,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Time segment (Right)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'TIME',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white.withValues(alpha: 0.4),
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                formattedTime,
                                                style: GoogleFonts.bebasNeue(
                                                  fontSize: 22,
                                                  color: Colors.white,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Zone & Confirmation Code Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              color: Colors.white.withValues(alpha: 0.4),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'ZONE 4 SECTOR B',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _confCode,
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withValues(alpha: 0.4),
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
                      ),

                      const SizedBox(height: 24),

                      // 5. ACTION MATRIX BUTTONS
                      Column(
                        children: [
                          // ADD TO CALENDAR (Solid White Button)
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16),
                                const SizedBox(width: 10),
                                Text(
                                  'ADD TO CALENDAR',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // RETURN TO DASHBOARD (Outlined Grey Button)
                          OutlinedButton(
                            onPressed: () {
                              // Reset navigation history stack cleanly back to dashboard
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/dashboard',
                                (route) => false,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grid_view_outlined, size: 16),
                                const SizedBox(width: 10),
                                Text(
                                  'RETURN TO DASHBOARD',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // 6. FOOTER TELEMETRY DECOR
                      Opacity(
                        opacity: 0.2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DATA_LATENCY: 12MS',
                                  style: GoogleFonts.inter(fontSize: 8, letterSpacing: -0.2),
                                ),
                                Text(
                                  'AUTH_STATUS: VERIFIED',
                                  style: GoogleFonts.inter(fontSize: 8, letterSpacing: -0.2),
                                ),
                              ],
                            ),
                            Container(
                              width: 32,
                              height: 1,
                              color: Colors.white,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ENCRYPTION: AES-256',
                                  style: GoogleFonts.inter(fontSize: 8, letterSpacing: -0.2),
                                ),
                                Text(
                                  'KINETIC_OS_V2.0',
                                  style: GoogleFonts.inter(fontSize: 8, letterSpacing: -0.2),
                                ),
                              ],
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

  // Segment row helper
  Widget _buildDetailRow(String label, String value, {required bool isBebas}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: isBebas
                ? GoogleFonts.bebasNeue(
                    fontSize: 22,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  )
                : GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}
