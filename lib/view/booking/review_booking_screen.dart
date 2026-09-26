import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';

class ReviewBookingScreen extends StatelessWidget {
  const ReviewBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final PractitionerRoleBooking? specialist = args['specialist'] as PractitionerRoleBooking?;
    final String specialistName = args['name'] as String? ?? 'Clinical Specialist';
    final String specialistRole = args['role'] as String? ?? 'General Practice';
    final String date = args['date'] as String? ?? 'Today';
    final DateTime dateRaw = args['date_raw'] as DateTime? ?? DateTime.now();
    final String time = args['time'] as String? ?? '10:00 AM';
    final String imageUrl = args['imageUrl'] as String? ?? 'assets/doctors/doctor_1.png';
    final bool isVirtual = args['isVirtual'] as bool? ?? true;
    final int? slotId = args['slot_id'] as int?;

    final bookingVM = context.watch<BookingViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Confirm Consultation',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Doctor Profile Card
                  Container(
                    decoration: BoxDecoration(
                      color: PhiaColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PhiaColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: PhiaColors.surfaceSubtle,
                            child: SafeNetworkImage(
                              imageUrl: imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              fallbackIcon: Icons.person,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: PhiaColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  specialistRole.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: PhiaColors.navyAnchor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                specialistName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'DrGodly Verified Physician',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: PhiaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Appointment Details Card (Deep Navy Header)
                  _buildNavyCard(
                    title: 'Appointment Details',
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            icon: Icons.calendar_today_rounded,
                            title: 'Date',
                            value: date,
                          ),
                          const Divider(color: PhiaColors.borderSubtle, height: 20),
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            title: 'Time',
                            value: time,
                          ),
                          const Divider(color: PhiaColors.borderSubtle, height: 20),
                          _buildDetailRow(
                            icon: isVirtual ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                            title: 'Consultation Format',
                            value: isVirtual ? 'Standard Video Consultation' : 'In-Clinic Physical Visit',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Summary Card (Deep Navy Header)
                  _buildNavyCard(
                    title: 'Consultation Fee Summary',
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildFeeRow('Clinical Specialist Fee', '\$100.00'),
                          const SizedBox(height: 8),
                          _buildFeeRow('DrGodly Platform Telemetry', '\$20.00'),
                          const Divider(color: PhiaColors.borderSubtle, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Payable',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              Text(
                                '\$120.00',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: PhiaColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Bottom Confirmation Bar
            Container(
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                border: const Border(top: BorderSide(color: PhiaColors.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: bookingVM.isBookingExecuting
                      ? null
                      : () async {
                          final cleanTime = time.split(' ')[0];
                          final parts = cleanTime.split(':');
                          int hour = int.tryParse(parts[0]) ?? 10;
                          int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                          if (time.toUpperCase().contains('PM') && hour < 12) hour += 12;
                          if (time.toUpperCase().contains('AM') && hour == 12) hour = 0;

                          final int pId = specialist?.practitionerRefId ?? specialist?.id ?? 1;

                          try {
                            final result = await context.read<BookingViewModel>().executeBooking(
                                  practitionerId: pId,
                                  practitionerName: specialistName,
                                  practitionerRole: specialistRole,
                                  practitionerImage: imageUrl,
                                  date: dateRaw,
                                  timeString: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                  isVirtual: isVirtual,
                                  slotId: slotId,
                                );

                            if (context.mounted) {
                              if (result.isNotEmpty && result['appointment_id'] != null) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/booking_confirmed',
                                  (route) => false,
                                  arguments: {
                                    'practitionerName': specialistName,
                                    'practitionerRole': specialistRole,
                                    'date': date,
                                    'time': time,
                                    'isVirtual': isVirtual,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to confirm appointment. Please check connection.'),
                                    backgroundColor: PhiaColors.pulseRed,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Booking error: ${e.toString().replaceAll('Exception: ', '')}'),
                                  backgroundColor: PhiaColors.pulseRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: bookingVM.isBookingExecuting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Confirm Appointment · \$120.00',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavyCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PhiaColors.navyAnchor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PhiaColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: PhiaColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textMuted),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.navyAnchor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRow(String title, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textSecondary),
        ),
        Text(
          amount,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: PhiaColors.textPrimary),
        ),
      ],
    );
  }
}
