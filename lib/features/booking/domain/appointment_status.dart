import 'package:phia_flutter/core/theme/app_colors.dart';

/// How an appointment status is shown to the patient.
///
/// Every screen uses this one mapping so the same appointment never reads
/// "CONFIRMED" in one place and "BOOKED" or "Cancelled" in another.
class AppointmentStatusStyle {
  final String label;
  final String description;
  /// Colour family; the theme turns it into readable light/dark colours.
  final StatusTone tone;

  const AppointmentStatusStyle({
    required this.label,
    required this.description,
    required this.tone,
  });

  /// [status] is the normalized status from BookingViewModel. [isPast] is true
  /// once the appointment time has gone by: a past "booked" visit is not
  /// claimed as completed, because only the server can say it took place.
  factory AppointmentStatusStyle.of(String? status, {bool isPast = false}) {
    switch ((status ?? '').toLowerCase()) {
      case 'fulfilled':
      case 'completed':
        return const AppointmentStatusStyle(
          label: 'COMPLETED',
          description: 'Consultation completed',
          tone: StatusTone.success,
        );
      case 'noshow':
      case 'no-show':
        return const AppointmentStatusStyle(
          label: 'MISSED',
          description: 'This consultation was missed',
          tone: StatusTone.neutral,
        );
      case 'cancelled':
      case 'canceled':
        return const AppointmentStatusStyle(
          label: 'CANCELLED',
          description: 'This consultation was cancelled',
          tone: StatusTone.danger,
        );
    }

    if (isPast) {
      return const AppointmentStatusStyle(
        label: 'PAST',
        description: 'The appointment time has passed',
        tone: StatusTone.neutral,
      );
    }

    switch ((status ?? '').toLowerCase()) {
      case 'confirmed':
        return const AppointmentStatusStyle(
          label: 'CONFIRMED',
          description: 'Confirmed by the doctor',
          tone: StatusTone.success,
        );
      case 'booked':
        return const AppointmentStatusStyle(
          label: 'BOOKED',
          description: 'Your time slot is booked',
          tone: StatusTone.info,
        );
      case 'rescheduled':
        return const AppointmentStatusStyle(
          label: 'RESCHEDULED',
          description: 'Moved to a new time',
          tone: StatusTone.accent,
        );
      default:
        return const AppointmentStatusStyle(
          label: 'PENDING',
          description: 'Awaiting doctor confirmation',
          tone: StatusTone.warning,
        );
    }
  }
}
