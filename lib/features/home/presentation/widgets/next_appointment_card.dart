import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/booking/domain/appointment_status.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/home/presentation/widgets/doctor_avatar.dart';
import 'package:provider/provider.dart';

/// How long a visit stays on Home after it starts. The app has no end time
/// for appointments, so a 30-minute consultation is assumed.
const Duration kVisitWindow = Duration(minutes: 30);

/// The nearest visit that is still upcoming or happening now, or null.
Map<String, dynamic>? findNextAppointment(List<Map<String, dynamic>> appointments, {DateTime? now}) {
  final at = now ?? DateTime.now();
  Map<String, dynamic>? next;
  DateTime? nextStart;
  for (final appt in appointments) {
    final status = (appt['status']?.toString() ?? '').toLowerCase();
    if (const {'fulfilled', 'noshow', 'cancelled', 'canceled'}.contains(status)) continue;
    final start = DateTime.tryParse(appt['start_time']?.toString() ?? '')?.toLocal();
    if (start == null || !start.add(kVisitWindow).isAfter(at)) continue;
    if (nextStart == null || start.isBefore(nextStart)) {
      next = appt;
      nextStart = start;
    }
  }
  return next;
}

/// Null-safe view of one appointment row.
class _Visit {
  final String id;
  final String name;
  final String role;
  final String image;
  final DateTime? start;
  final bool isVirtual;
  final String status;

  _Visit(Map<String, dynamic> a)
      : id = a['id']?.toString() ?? '',
        name = (a['practitioner_name']?.toString().trim().isNotEmpty ?? false)
            ? a['practitioner_name'].toString().trim()
            : 'Your doctor',
        role = a['practitioner_role']?.toString().trim() ?? '',
        image = a['practitioner_image']?.toString() ?? '',
        start = DateTime.tryParse(a['start_time']?.toString() ?? '')?.toLocal(),
        isVirtual = (int.tryParse(a['is_virtual']?.toString() ?? '') ?? 1) == 1,
        status = a['status']?.toString().toLowerCase() ?? 'pending';

  String get when => start == null ? 'Time not available' : DateFormat('EEE, d MMM · h:mm a').format(start!);
  String get type => isVirtual ? 'Video visit' : 'In-clinic visit';
  bool get isNow {
    final s = start;
    if (s == null) return false;
    final n = DateTime.now();
    return !n.isBefore(s) && n.isBefore(s.add(kVisitWindow));
  }
}

/// Home's hero card: the next visit, or a clear way to book one.
class NextAppointmentCard extends StatelessWidget {
  final Map<String, dynamic>? appointment;
  final VoidCallback onBook;

  const NextAppointmentCard({super.key, required this.appointment, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    if (appt == null) return _EmptyVisitCard(onBook: onBook);

    final colors = context.colors;
    final v = _Visit(appt);
    final style = AppointmentStatusStyle.of(v.status);

    return AppCard(
      onTap: () => showAppointmentDetails(context, appt),
      semanticLabel: 'Next visit with ${v.name}, ${v.when}, ${style.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v.isNow ? 'Happening now' : 'Next visit',
                  style: context.text.labelLarge!.copyWith(color: colors.primary),
                ),
              ),
              StatusBadge(label: style.label, tone: style.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              DoctorAvatar(name: v.name, imageUrl: v.image),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (v.role.isNotEmpty)
                      Text(
                        v.role,
                        style: context.text.bodySmall!.copyWith(color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoLine(icon: Icons.event_rounded, text: v.when),
          const SizedBox(height: AppSpacing.xs),
          _InfoLine(
            icon: v.isVirtual ? Icons.videocam_outlined : Icons.local_hospital_outlined,
            text: v.type,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'View details',
            onPressed: () => showAppointmentDetails(context, appt),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: context.text.bodyMedium!.copyWith(color: colors.textSecondary))),
      ],
    );
  }
}

class _EmptyVisitCard extends StatelessWidget {
  final VoidCallback onBook;
  const _EmptyVisitCard({required this.onBook});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: AppRadius.mdAll),
                child: Icon(Icons.event_available_rounded, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('No upcoming visits', style: context.text.titleMedium)),
                    Text(
                      'See a verified doctor by video or in person.',
                      style: context.text.bodySmall!.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Book a doctor', icon: Icons.search_rounded, onPressed: onBook),
        ],
      ),
    );
  }
}

/// Bottom sheet with the full visit details, Reschedule and Cancel.
Future<void> showAppointmentDetails(BuildContext context, Map<String, dynamic> appt) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    builder: (sheetContext) => _DetailsSheet(appt: appt, hostContext: context),
  );
}

class _DetailsSheet extends StatelessWidget {
  final Map<String, dynamic> appt;

  /// The dashboard's context: still valid after this sheet closes.
  final BuildContext hostContext;

  const _DetailsSheet({required this.appt, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = _Visit(appt);
    final style = AppointmentStatusStyle.of(v.status);
    final date = v.start == null ? 'Time not available' : DateFormat('EEEE, d MMMM yyyy').format(v.start!);
    final time = v.start == null ? '' : DateFormat('h:mm a').format(v.start!);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Visit details', style: context.text.titleLarge)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              DoctorAvatar(name: v.name, imageUrl: v.image, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, style: context.text.titleMedium),
                    if (v.role.isNotEmpty)
                      Text(v.role, style: context.text.bodySmall!.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _DetailRow(label: 'Date', value: date),
          if (time.isNotEmpty) _DetailRow(label: 'Time', value: time),
          _DetailRow(label: 'Type', value: v.type),
          const SizedBox(height: AppSpacing.sm),
          Text('Status', style: context.text.labelMedium!.copyWith(color: colors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Align(alignment: Alignment.centerLeft, child: StatusBadge(label: style.label, tone: style.tone)),
          const SizedBox(height: AppSpacing.xs),
          Text(style.description, style: context.text.bodyMedium!.copyWith(color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          AppButton.secondary(
            label: 'Reschedule',
            icon: Icons.edit_calendar_rounded,
            onPressed: () {
              Navigator.pop(context);
              _reschedule(hostContext, appt, v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.text(
            label: 'Cancel visit',
            expand: true,
            onPressed: () {
              Navigator.pop(context);
              _cancel(hostContext, v);
            },
          ),
        ],
      ),
    );
  }

  void _reschedule(BuildContext context, Map<String, dynamic> appt, _Visit v) {
    if (!context.mounted) return;
    final specialist = context.read<BookingViewModel>().findSpecialistForAppointment(appt);
    if (specialist == null) {
      showAppMessage(
        context,
        "${v.name} isn't in the current doctor list, so this visit can't be moved in the app. "
        'Cancel it and book a new time instead.',
      );
      return;
    }
    context.push(AppRoutes.bookingTime, extra: {
      'specialist': specialist,
      'name': v.name,
      'role': v.role,
      'imageUrl': v.image,
      'reschedule_appointment_id': v.id,
    });
  }

  Future<void> _cancel(BuildContext context, _Visit v) async {
    if (!context.mounted || v.id.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: 'Cancel this visit?',
      message: 'Your visit with ${v.name} on ${v.when} will be cancelled.',
      confirmLabel: 'Cancel visit',
      cancelLabel: 'Keep visit',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final vm = context.read<BookingViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    // The server can take a few seconds; show that work is happening.
    messenger.showSnackBar(const SnackBar(content: Text('Cancelling visit…'), duration: Duration(seconds: 30)));
    try {
      await vm.cancelAppointment(v.id);
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        showAppMessage(context, 'Your visit with ${v.name} is cancelled.', type: FeedbackType.success);
      }
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        showAppMessage(
          context,
          "Couldn't cancel the visit. Check your connection and try again.",
          type: FeedbackType.error,
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelMedium!.copyWith(color: colors.textMuted)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: context.text.bodyLarge),
        ],
      ),
    );
  }
}
