import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/config/api_constants.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/data/booking_repository.dart' show SlotTakenException;
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:provider/provider.dart';

/// "Check your visit": a summary of the choice and one button to book it.
class ReviewBookingScreen extends StatefulWidget {
  const ReviewBookingScreen({super.key});

  @override
  State<ReviewBookingScreen> createState() => _ReviewBookingScreenState();
}

class _ReviewBookingScreenState extends State<ReviewBookingScreen> {
  /// True from the first tap until we leave this screen or the attempt fails.
  /// Covers the whole flow (booking + intake linking), not only the booking
  /// call, so a second tap can't book the same slot again and get a 409.
  bool _submitting = false;

  Map<String, dynamic> get _args {
    final extra = GoRouterState.of(context).extra;
    return extra is Map<String, dynamic> ? extra : const {};
  }

  Future<void> _confirm() async {
    final args = _args;
    final specialist = args['specialist'] as PractitionerRoleBooking?;
    final name = honestName(args['name'] as String?);
    final role = honestRole(args['role'] as String?);
    final imageUrl = args['imageUrl'] as String? ?? '';
    final date = args['date'] as String? ?? '';
    final dateRaw = args['date_raw'] as DateTime?;
    final time = args['time'] as String? ?? '';
    final isVirtual = args['isVirtual'] as bool? ?? true;
    final slotId = args['slot_id'] as int?;

    // `practitioner_id` is the Practitioner id from practitioner_detail.id,
    // never the PractitionerRole id (patient guide §4.3).
    final int? pId = specialist?.practitionerDetail?.id;
    if (pId == null || slotId == null || slotId <= 0 || dateRaw == null || time.isEmpty) {
      showAppMessage(
        context,
        'Please go back and choose a doctor and an available time.',
        type: FeedbackType.error,
      );
      return;
    }

    final cleanTime = time.split(' ')[0];
    final parts = cleanTime.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (time.toUpperCase().contains('PM') && hour < 12) hour += 12;
    if (time.toUpperCase().contains('AM') && hour == 12) hour = 0;

    setState(() => _submitting = true);
    var leftScreen = false;
    try {
      final result = await context.read<BookingViewModel>().executeBooking(
            practitionerId: pId,
            practitionerName: name,
            practitionerRole: role,
            practitionerImage: imageUrl,
            date: dateRaw,
            timeString: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            isVirtual: isVirtual,
            slotId: slotId,
          );
      if (!mounted) return;
      if (result.isEmpty || result['appointment_id'] == null) {
        showAppMessage(
          context,
          "Couldn't book your visit. Check your connection and try again.",
          type: FeedbackType.error,
        );
        return;
      }

      final aptId = result['appointment_id'] is int
          ? result['appointment_id'] as int
          : int.tryParse(result['appointment_id'].toString()) ?? 0;
      var intakeShared = false;
      if (aptId > 0) {
        final intakeVM = context.read<IntakeViewModel>();
        final authVM = context.read<AuthViewModel>();
        try {
          intakeShared = await intakeVM.linkToAppointment(
            intakeRecordId: args['intakeId'] as int?,
            fhirAppointmentId: aptId,
            authToken: authVM.jwtToken ?? '',
            orgId:
                (authVM.orgId != null && authVM.orgId!.isNotEmpty) ? authVM.orgId : ApiConstants.defaultOrganizationId,
          );
        } catch (e) {
          debugPrint('[ReviewBookingScreen] Error linking intake to appointment: $e');
        }
      }
      if (!mounted) return;
      leftScreen = true;
      context.go(AppRoutes.bookingConfirmed, extra: {
        'practitionerName': name,
        'practitionerRole': role,
        'date': date,
        'time': time,
        'isVirtual': isVirtual,
        'intakeShared': intakeShared,
      });
    } on SlotTakenException {
      // 409: go back to the time picker, which reloads the free slots
      // (patient guide §4.3).
      if (mounted) {
        leftScreen = true;
        context.pop('slot_taken');
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          "Couldn't book your visit: ${e.toString().replaceAll('Exception: ', '')}",
          type: FeedbackType.error,
        );
      }
    } finally {
      if (!leftScreen && mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final name = honestName(args['name'] as String?);
    final role = honestRole(args['role'] as String?);
    final isVirtual = args['isVirtual'] as bool? ?? true;
    final hasIntake = args['intakeCompleted'] == true && args['intakeId'] != null;
    final busy = _submitting || context.watch<BookingViewModel>().isBookingExecuting;

    return Scaffold(
      appBar: AppBar(title: const Text('Check your visit')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  FadeSlideIn(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DoctorHeader(name: name, role: role, photoUrl: args['imageUrl'] as String?),
                          const Divider(height: AppSpacing.xl),
                          SummaryRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Date',
                            value: (args['date'] as String?)?.isNotEmpty == true ? args['date'] as String : '--',
                          ),
                          SummaryRow(
                            icon: Icons.schedule_rounded,
                            label: 'Time',
                            value: (args['time'] as String?)?.isNotEmpty == true ? args['time'] as String : '--',
                          ),
                          SummaryRow(
                            icon: isVirtual ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                            label: 'Visit type',
                            value: isVirtual ? 'Video visit' : 'In-person visit',
                          ),
                          SummaryRow(
                            icon: Icons.assignment_rounded,
                            label: 'Symptom summary',
                            value: hasIntake ? 'Will be shared with your doctor' : 'Not added',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: AppSizes.iconSm, color: context.colors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'You can cancel or move this visit later from My appointments.',
                          style: context.text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: 'Confirm appointment',
                icon: Icons.check_rounded,
                isLoading: busy,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
