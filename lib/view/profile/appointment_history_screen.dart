import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';

class AppointmentHistoryScreen extends StatelessWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingVM = context.watch<BookingViewModel>();
    final now = DateTime.now();

    // Separate appointments into upcoming and past
    final upcomingAppts = <Map<String, dynamic>>[];
    final pastAppts = <Map<String, dynamic>>[];

    for (var appt in bookingVM.appointmentsList) {
      try {
        final startTime = DateTime.parse(appt['start_time'] as String).toLocal();
        if (startTime.isAfter(now)) {
          upcomingAppts.add(appt);
        } else {
          pastAppts.add(appt);
        }
      } catch (e) {
        // Fallback: put in past if parsing fails
        pastAppts.add(appt);
      }
    }

    // Sort upcoming ascending (nearest first)
    upcomingAppts.sort((a, b) => a['start_time'].compareTo(b['start_time']));
    // Sort past descending (most recent first)
    pastAppts.sort((a, b) => b['start_time'].compareTo(a['start_time']));

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'APPOINTMENT HISTORY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 22,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      // Upcoming Section
                      _buildSectionHeader('UPCOMING CONSULTATIONS'),
                      if (upcomingAppts.isEmpty)
                        _buildEmptyState('NO UPCOMING APPOINTMENTS')
                      else
                        ...upcomingAppts.map((appt) => _buildAppointmentCard(context, appt, isUpcoming: true)),
                      
                      const SizedBox(height: 32),

                      // Past Section
                      _buildSectionHeader('PAST CONSULTATION RECORD'),
                      if (pastAppts.isEmpty)
                        _buildEmptyState('NO PAST SESSIONS FOUND')
                      else
                        ...pastAppts.map((appt) => _buildAppointmentCard(context, appt, isUpcoming: false)),
                      
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            color: PhiaColors.skyBlue,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.bebasNeue(
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.bebasNeue(
            fontSize: 14,
            color: Colors.white30,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Map<String, dynamic> appt, {required bool isUpcoming}) {
    final id = appt['id'] as String;
    final name = appt['practitioner_name'] as String;
    final role = appt['practitioner_role'] as String;
    final image = appt['practitioner_image'] as String;
    final startTimeStr = appt['start_time'] as String;
    final type = appt['type'] as String;
    final isVirtual = (appt['is_virtual'] as int? ?? 1) == 1;

    String dateFormatted = '';
    String timeFormatted = '';
    try {
      final dateTime = DateTime.parse(startTimeStr).toLocal();
      dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(dateTime).toUpperCase();
      timeFormatted = DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      dateFormatted = startTimeStr;
    }

    final String fallbackImageUrl = 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?q=80&w=100';
    final imageUrl = image.isNotEmpty ? image : fallbackImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUpcoming ? PhiaColors.surface : Colors.transparent,
        border: Border.all(
          color: isUpcoming 
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Avatar (Grayscale)
              Container(
                width: 48,
                height: 60,
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
              // Doctor details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVirtual ? 'VIRTUAL CONSULTATION' : 'IN-PERSON VISIT',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isUpcoming ? PhiaColors.skyBlue : Colors.white30,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.toUpperCase(),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 18,
                        color: isUpcoming ? Colors.white : Colors.white60,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      role.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Time/Date row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isUpcoming ? Colors.white70 : Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  timeFormatted,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 16,
                    color: isUpcoming ? Colors.white : Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25)),
                minimumSize: const Size(double.infinity, 40),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () {
                _showCancelConfirmation(context, id, name);
              },
              child: Text(
                'CANCEL CONSULTATION',
                style: GoogleFonts.bebasNeue(
                  fontSize: 12,
                  color: Colors.redAccent,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, String id, String doctorName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: const Border(
            top: BorderSide(color: Colors.redAccent, width: 2.0),
          ),
          title: Text(
            'CANCEL APPOINTMENT',
            style: GoogleFonts.bebasNeue(
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel your scheduled appointment with $doctorName?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'KEEP IT',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () {
                context.read<BookingViewModel>().cancelAppointment(id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Appointment with $doctorName cancelled.')),
                );
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.bebasNeue(
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
