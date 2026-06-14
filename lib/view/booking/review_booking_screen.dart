import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';
import '../../core/utils/language_helper.dart';

class ReviewBookingScreen extends StatelessWidget {
  const ReviewBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve booking details passed from select_date_time_screen.dart
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final PractitionerRoleBooking? specialist = args['specialist'] as PractitionerRoleBooking?;
    final String specialistName = args['name'] as String;
    final String specialistRole = args['role'] as String;
    final Color accentColor = args['accentColor'] as Color;
    final String date = args['date'] as String; // e.g. "October 7, 2026"
    final DateTime dateRaw = args['date_raw'] as DateTime;
    final String time = args['time'] as String; // "08:00"
    final String imageUrl = args['imageUrl'] as String;
    final bool isVirtual = args['isVirtual'] as bool? ?? true;

    // Parse the date parameter (e.g. "October 7, 2026" -> day "07", month "OCT")
    String dayNum = '07';
    String monthAbbr = 'OCT';
    String dayCycle = 'SATURDAY_CY26';
    
    try {
      final cleanDate = date.replaceAll(',', '');
      final parts = cleanDate.split(' ');
      if (parts.length >= 2) {
        dayNum = parts[1].padLeft(2, '0');
        final fullMonth = parts[0];
        monthAbbr = fullMonth.length > 3 ? fullMonth.substring(0, 3).toUpperCase() : fullMonth.toUpperCase();
      }
      
      final cleanYear = dateRaw.year.toString().substring(2);
      final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      final weekdayName = weekdays[dateRaw.weekday - 1];
      dayCycle = '${weekdayName}_CY$cleanYear';
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      ),
                      Text(
                        'DRGODLY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      const UserHeaderAvatar(),
                    ],
                  ),
                ),

                // Main Content List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLINICAL ENCOUNTER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.38),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLanguageHelper.translate(context, 'review_booking', defaultText: 'REVIEW BOOKING'),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. BOOKING BILL OVERVIEW BENTO BOX
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SEGMENT A: PATIENT/SPECIALIST INFRASTRUCTURE MAPPING
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // desaturated doctor image
                                  Container(
                                    width: 50,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                      image: DecorationImage(
                                        image: getImageProvider(imageUrl, fallback: 'assets/doctors/doctor_1.png'),
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
                                          specialistRole.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          specialistName.toUpperCase(),
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 20,
                                            color: Colors.white,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        // Removed Practitioner FHIR ID label for cleaner UI
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            _buildHorizontalDivider(),

                            // SEGMENT B: CALENDAR DATETIME BLOCKS
                            Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CALENDAR MAPPING',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withValues(alpha: 0.4),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              dayNum,
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 32,
                                                color: Colors.white,
                                                height: 0.8,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  monthAbbr,
                                                  style: GoogleFonts.bebasNeue(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Text(
                                                  dayCycle,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 7,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _buildVerticalDivider(),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'WINDOW TIMINGS',
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
                                          'LOCAL DEVICE TIME',
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
                                    'APPOINTMENT TYPE',
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
                                        isVirtual ? 'VIRTUAL CLINICAL CONSULTATION' : 'IN-PERSON CLINICAL VISIT',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 18,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Icon(isVirtual ? Icons.computer : Icons.location_on, color: Colors.white, size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isVirtual
                                        ? 'Secure clinical tele-consultation enabled with dynamic HD video channels and automated telemetry logs synced directly to your secure health record.'
                                        : 'In-person ambulatory diagnostic visit scheduled at the DRGODLY Clinical Wellness Center.',
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
                          'By confirming, you authorize DRGODLY to dynamically write planned Encounter and booked Appointment resources to your secure health record.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.35),
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 5. CONFIRM BOOKING CTA with Consumer overlay
                      Consumer<BookingViewModel>(
                        builder: (context, vm, child) {
                          return ElevatedButton(
                            onPressed: vm.isBookingExecuting
                                ? null
                                : () {
                                    final pId = specialist?.practitionerRefId ?? specialist?.id;
                                    if (pId == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: PhiaColors.pulseRed,
                                          content: Text('Error: Specialist details are invalid.'),
                                        ),
                                      );
                                      return;
                                    }

                                    final navigator = Navigator.of(context);
                                    final messenger = ScaffoldMessenger.of(context);

                                    vm.executeBooking(
                                      practitionerId: pId,
                                      practitionerName: specialistName,
                                      practitionerRole: specialistRole,
                                      practitionerImage: imageUrl,
                                      date: dateRaw,
                                      timeString: time,
                                      isVirtual: isVirtual,
                                      note: 'Clinical Specialist Consultation',
                                    ).then((result) {
                                      navigator.pushNamedAndRemoveUntil(
                                        '/booking_confirmed',
                                        (route) => route.settings.name == '/dashboard',
                                        arguments: {
                                          'name': specialistName,
                                          'date': date,
                                          'time': time,
                                          'accentColor': accentColor,
                                          'result': result,
                                        },
                                      );
                                    }).catchError((err) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: PhiaColors.pulseRed,
                                          content: Text(
                                            'TRANSACTION ERROR: ${err.toString().replaceAll('Exception: ', '')}',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                              disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              elevation: 0,
                            ),
                            child: vm.isBookingExecuting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'CONFIRMING APPOINTMENT...',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
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
                          );
                        },
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
