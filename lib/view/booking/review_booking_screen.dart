import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class ReviewBookingScreen extends StatelessWidget {
  const ReviewBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve booking details passed from select_date_time_screen.dart
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String specialistName = args['name'] as String;
    final String specialistRole = args['role'] as String;
    final Color accentColor = args['accentColor'] as Color;
    final String date = args['date'] as String; // "OCTOBER 07, 2023"
    final String time = args['time'] as String; // "08:00"
    final String imageUrl = args['imageUrl'] as String;

    // Parse the date parameter (e.g. "OCTOBER 07, 2023" -> day "07", month "OCT")
    String dayNum = '07';
    String monthAbbr = 'OCT';
    String dayCycle = 'SATURDAY_CY23';
    
    try {
      final cleanDate = date.replaceAll(',', '');
      final parts = cleanDate.split(' ');
      if (parts.length >= 2) {
        dayNum = parts[1].padLeft(2, '0');
        final fullMonth = parts[0];
        monthAbbr = fullMonth.length > 3 ? fullMonth.substring(0, 3).toUpperCase() : fullMonth.toUpperCase();
      }
      
      // Deduce the weekday cycle dynamically
      if (parts.length >= 3) {
        final year = parts[2];
        final cleanYear = year.substring(max(0, year.length - 2));
        final monthsMap = {
          'JANUARY': 1, 'FEBRUARY': 2, 'MARCH': 3, 'APRIL': 4, 'MAY': 5, 'JUNE': 6,
          'JULY': 7, 'AUGUST': 8, 'SEPTEMBER': 9, 'OCTOBER': 10, 'NOVEMBER': 11, 'DECEMBER': 12
        };
        final mInt = monthsMap[parts[0].toUpperCase()] ?? 10;
        final dInt = int.tryParse(parts[1]) ?? 7;
        final yInt = int.tryParse(parts[2]) ?? 2023;
        final parsedDate = DateTime(yInt, mInt, dInt);
        final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
        final weekdayName = weekdays[parsedDate.weekday - 1];
        dayCycle = '${weekdayName}_CY$cleanYear';
      }
    } catch (e) {
      // Swallowed safely, fallbacks stand
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
                        onPressed: () => Navigator.pop(context),
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

                      // Reference Protocol Info Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REFERENCE_PROTOCOL',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SESSION_ID: BK-772',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'STATUS',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Outlined Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 1.0),
                                ),
                                child: Text(
                                  'PENDING_CONFIRMATION',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Title Area (REVIEW SESSION with custom bottom horizontal rule)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REVIEW SESSION',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 32,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 1.5,
                            width: 60,
                            color: Colors.white,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 3. SEGMENTED BENTO REVIEW CARD CONTAINER
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SEGMENT A: LEAD SPECIALIST
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LEAD SPECIALIST',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Square grayscale specialist photo inside a thin white box
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white, width: 1.0),
                                          image: DecorationImage(
                                            image: NetworkImage(imageUrl),
                                            fit: BoxFit.cover,
                                            colorFilter: const ColorFilter.matrix(<double>[
                                              0.2126, 0.7152, 0.0722, 0, -20,
                                              0.2126, 0.7152, 0.0722, 0, -20,
                                              0.2126, 0.7152, 0.0722, 0, -20,
                                              0,      0,      0,      1, 0,
                                            ]),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              specialistName.toUpperCase(),
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 22,
                                                color: Colors.white,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              specialistRole,
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white.withValues(alpha: 0.4),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            _buildHorizontalDivider(),

                            // SEGMENT B: DATE & TIME SPLIT GRID
                            Row(
                              children: [
                                // Date Column (Left)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                                        const SizedBox(height: 8),
                                        Text(
                                          '$dayNum $monthAbbr',
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 26,
                                            color: Colors.white,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dayCycle,
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withValues(alpha: 0.35),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                _buildVerticalDivider(),

                                // Time Column (Right)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                                        const SizedBox(height: 8),
                                        Text(
                                          time,
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 26,
                                            color: Colors.white,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'GMT +01:00',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withValues(alpha: 0.35),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            _buildHorizontalDivider(),

                            // SEGMENT C: SESSION TYPE DETAILS
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SESSION TYPE',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ELITE CALIBRATION',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const Icon(Icons.bolt, color: Colors.white, size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Full-body biometric sync and neural pathway stimulation for peak performance recovery.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.38),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. AUTHORIZATION CONSENT DISCLAIMER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'By confirming, you authorize KINETIC to synchronize biometric data during the session. Cancellation protocol requires 24h notice for credit reclamation.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.35),
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 5. CONFIRM BOOKING CTA (Solid White Block Button with Right Arrow)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/booking_confirmed',
                            (route) => route.settings.name == '/dashboard',
                            arguments: {
                              'name': specialistName,
                              'date': date,
                              'time': time,
                              'accentColor': accentColor,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CONFIRM BOOKING',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
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

  // Border layout dividers helpers
  Widget _buildHorizontalDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 70,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}
