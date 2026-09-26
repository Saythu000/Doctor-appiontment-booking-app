import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';

class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final doctorName = args?['practitionerName'] as String? ?? 'DrGodly Specialist';
    final doctorRole = args?['practitionerRole'] as String? ?? 'General Practice';
    final date = args?['date'] as String? ?? 'Upcoming Date';
    final time = args?['time'] as String? ?? 'Scheduled Time';
    final isVirtual = args?['isVirtual'] as bool? ?? true;

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Success Icon Circle
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: PhiaColors.activeGreenBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: PhiaColors.activeGreen.withValues(alpha: 0.4), width: 3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: PhiaColors.activeGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title & Confirmation
              Text(
                'Consultation Confirmed!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: PhiaColors.navyAnchor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your visit is confirmed within the DrGodly clinical network. Real-time notifications and reminders are active.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: PhiaColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Appointment Receipt Card (Navy Header Banner)
              Container(
                decoration: BoxDecoration(
                  color: PhiaColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PhiaColors.borderSubtle, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: PhiaColors.navyAnchor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      width: double.infinity,
                      child: Text(
                        'Appointment Confirmation Receipt',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: PhiaColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.person_rounded, color: PhiaColors.navyAnchor, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doctorName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: PhiaColors.navyAnchor,
                                      ),
                                    ),
                                    Text(
                                      doctorRole,
                                      style: GoogleFonts.inter(fontSize: 12, color: PhiaColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: PhiaColors.borderSubtle, height: 1),
                          const SizedBox(height: 14),
                          _buildRow(Icons.calendar_month_rounded, 'Date', date),
                          const SizedBox(height: 10),
                          _buildRow(Icons.schedule_rounded, 'Time', time),
                          const SizedBox(height: 10),
                          _buildRow(
                            isVirtual ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                            'Type',
                            isVirtual ? 'Standard Video Consultation' : 'In-Clinic Physical Visit',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Return to Dashboard CTA
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  'Go to Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PhiaColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PhiaColors.navyAnchor,
          ),
        ),
      ],
    );
  }
}
