import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../data/repository/booking_repository.dart' show SlotTakenException;
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/intake_viewmodel.dart';
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

                          // `practitioner_id` is the Practitioner id from practitioner_detail.id,
                          // never the PractitionerRole id (patient guide §4.3).
                          final int? pId = specialist?.practitionerDetail?.id;
                          if (pId == null || slotId == null || slotId <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please go back and select a doctor and an available time slot.'),
                                backgroundColor: PhiaColors.pulseRed,
                              ),
                            );
                            return;
                          }

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
                                final aptId = result['appointment_id'] is int
                                    ? result['appointment_id'] as int
                                    : int.tryParse(result['appointment_id'].toString()) ?? 0;
                                final intakeVM = context.read<IntakeViewModel>();
                                final authVM = context.read<AuthViewModel>();
                                if (aptId > 0) {
                                  try {
                                    await intakeVM.linkToAppointment(
                                      intakeRecordId: args['intakeId'] as int?,
                                      fhirAppointmentId: aptId,
                                      authToken: authVM.jwtToken ?? '',
                                      orgId: (authVM.orgId != null && authVM.orgId!.isNotEmpty)
                                          ? authVM.orgId
                                          : ApiConstants.defaultOrganizationId,
                                    );
                                  } catch (e) {
                                    debugPrint('[ReviewBookingScreen] Error linking intake to appointment: $e');
                                  }
                                }

                                if (!context.mounted) return;

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
                          } on SlotTakenException {
                            // 409: go back to the time picker, which reloads
                            // the free slots (patient guide §4.3).
                            if (context.mounted) Navigator.pop(context, 'slot_taken');
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
                          'Confirm Appointment',
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
}
