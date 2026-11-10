import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/booking/domain/appointment_status.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';

/// Formats a stored ISO start time as ("Mon, Nov 11, 2026", "10:30 AM"),
/// or ("--", "") when it can't be read.
(String, String) formatAppointmentTime(String? iso) {
  final dt = DateTime.tryParse(iso ?? '')?.toLocal();
  if (dt == null) return ('--', '');
  return (DateFormat('EEE, MMM d, yyyy').format(dt), DateFormat('h:mm a').format(dt));
}

/// One appointment in My appointments. Upcoming visits get Move and Cancel.
class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isUpcoming;
  final bool cancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isUpcoming,
    this.cancelling = false,
    this.onCancel,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = honestName(appointment['practitioner_name'] as String?);
    final role = honestRole(appointment['practitioner_role'] as String?);
    final isVirtual = (appointment['is_virtual'] as int? ?? 1) == 1;
    final (date, time) = formatAppointmentTime(appointment['start_time'] as String?);
    final status = AppointmentStatusStyle.of(appointment['status'] as String?, isPast: !isUpcoming);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorAvatar(name: name, photoUrl: appointment['practitioner_image'] as String?, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.titleMedium),
                    if (role.isNotEmpty)
                      Text(role, style: context.text.bodySmall!.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusBadge(label: status.label, tone: status.tone),
                        StatusBadge(
                          label: isVirtual ? 'VIDEO' : 'IN PERSON',
                          tone: StatusTone.neutral,
                          icon: isVirtual ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: AppRadius.smAll),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                _IconText(icon: Icons.calendar_today_rounded, text: date),
                if (time.isNotEmpty) _IconText(icon: Icons.schedule_rounded, text: time),
              ],
            ),
          ),
          if (isUpcoming && (onCancel != null || onReschedule != null)) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (onReschedule != null)
                  AppButton.secondary(
                    label: 'Move',
                    icon: Icons.edit_calendar_rounded,
                    expand: false,
                    onPressed: cancelling ? null : onReschedule,
                  ),
                if (onCancel != null)
                  AppButton.danger(
                    label: cancelling ? 'Cancelling…' : 'Cancel',
                    icon: Icons.close_rounded,
                    expand: false,
                    isLoading: cancelling,
                    onPressed: onCancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: context.colors.primary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text, style: context.text.titleSmall)),
      ],
    );
  }
}
