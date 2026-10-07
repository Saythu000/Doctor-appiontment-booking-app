import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
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
        final status = (appt['status'] as String? ?? '').toLowerCase();
        final startTime = DateTime.parse(appt['start_time'] as String).toLocal();
        final isTerminated = status == 'fulfilled' || status == 'completed' || status == 'noshow' || status == 'no-show' || status == 'cancelled' || status == 'canceled';
        if (startTime.isAfter(now) && !isTerminated) {
          upcomingAppts.add(appt);
        } else {
          pastAppts.add(appt);
        }
      } catch (e) {
        // Fallback: put in past if parsing fails
        pastAppts.add(appt);
      }
    }

    // Sort upcoming: chronological ascending (nearest date first, earlier slot first)
    upcomingAppts.sort((a, b) {
      try {
        final dtA = DateTime.parse(a['start_time'] as String).toLocal();
        final dtB = DateTime.parse(b['start_time'] as String).toLocal();
        return dtA.compareTo(dtB);
      } catch (_) {
        return (a['start_time'] ?? '').compareTo(b['start_time'] ?? '');
      }
    });

    // ponytail: Sort past consultations with date descending (most recent days first) 
    // and time ascending within each day (morning to evening chronological reading order)
    pastAppts.sort((a, b) {
      try {
        final dtA = DateTime.parse(a['start_time'] as String).toLocal();
        final dtB = DateTime.parse(b['start_time'] as String).toLocal();

        final dateA = DateTime(dtA.year, dtA.month, dtA.day);
        final dateB = DateTime(dtB.year, dtB.month, dtB.day);
        final dateCompare = dateB.compareTo(dateA); // Newer date first

        if (dateCompare != 0) return dateCompare;

        // Same date: chronological time order (morning -> evening)
        final timeA = dtA.hour * 60 + dtA.minute;
        final timeB = dtB.hour * 60 + dtB.minute;
        return timeA.compareTo(timeB);
      } catch (_) {
        return (b['start_time'] ?? '').compareTo(a['start_time'] ?? '');
      }
    });

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appointment History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        children: [
          // Upcoming Section
          _buildSectionHeader('UPCOMING CONSULTATIONS'),
          if (upcomingAppts.isEmpty)
            _buildEmptyState('No upcoming appointments scheduled')
          else
            ...upcomingAppts.map((appt) => _buildAppointmentCard(context, appt, isUpcoming: true)),
          
          const SizedBox(height: 28),

          // Past Section
          _buildSectionHeader('PAST CONSULTATION RECORD'),
          if (pastAppts.isEmpty)
            _buildEmptyState('No past consultations found')
          else
            ...pastAppts.map((appt) => _buildAppointmentCard(context, appt, isUpcoming: false)),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: PhiaColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: PhiaColors.navyAnchor,
              letterSpacing: 0.8,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: PhiaColors.textMuted,
            fontWeight: FontWeight.w500,
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

    final status = (appt['status'] as String? ?? 'pending').toLowerCase();
    Color statusBg;
    Color statusTextColor;
    String statusLabel;
    switch (status) {
      case 'fulfilled':
      case 'completed':
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'FULFILLED';
        break;
      case 'noshow':
      case 'no-show':
        statusBg = const Color(0xFFF1F5F9);
        statusTextColor = const Color(0xFF64748B);
        statusLabel = 'MISSED';
        break;
      case 'booked':
      case 'confirmed':
        statusBg = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusLabel = 'CONFIRMED';
        break;
      case 'rescheduled':
        statusBg = const Color(0xFFEDE9FE);
        statusTextColor = const Color(0xFF6D28D9);
        statusLabel = 'RESCHEDULED';
        break;
      case 'cancelled':
      case 'canceled':
        statusBg = PhiaColors.pulseRedLight;
        statusTextColor = PhiaColors.pulseRed;
        statusLabel = 'CANCELLED';
        break;
      case 'pending':
      default:
        statusBg = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFB45309);
        statusLabel = 'PENDING';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUpcoming ? PhiaColors.borderSubtle : PhiaColors.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  color: PhiaColors.surfaceSubtle,
                  child: Image(
                    image: getImageProvider(imageUrl, fallback: 'assets/doctors/doctor_1.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Doctor details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: PhiaColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isVirtual ? 'VIDEO CONSULTATION' : 'IN-CLINIC VISIT',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.navyAnchor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PhiaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: PhiaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Time/Date row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: PhiaColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PhiaColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: PhiaColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      dateFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: PhiaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  timeFormatted,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: PhiaColors.pulseRed.withValues(alpha: 0.3)),
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _showCancelConfirmation(context, id, name);
              },
              child: Text(
                'Cancel Consultation',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PhiaColors.pulseRed,
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
          backgroundColor: PhiaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cancel Appointment',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: PhiaColors.navyAnchor,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel your scheduled appointment with $doctorName?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: PhiaColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Keep',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PhiaColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PhiaColors.pulseRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final bookingVM = context.read<BookingViewModel>();
                await bookingVM.cancelAppointment(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Appointment cancelled',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: PhiaColors.navyAnchor,
                    ),
                  );
                }
              },
              child: Text(
                'Cancel Visit',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
