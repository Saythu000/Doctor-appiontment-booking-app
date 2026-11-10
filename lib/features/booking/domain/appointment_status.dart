import 'package:flutter/material.dart';

import 'package:phia_flutter/core/theme/colors.dart';

/// How an appointment status is shown to the patient.
///
/// Every screen uses this one mapping so the same appointment never reads
/// "CONFIRMED" in one place and "BOOKED" or "Cancelled" in another.
class AppointmentStatusStyle {
  final String label;
  final String description;
  final Color background;
  final Color foreground;

  const AppointmentStatusStyle({
    required this.label,
    required this.description,
    required this.background,
    required this.foreground,
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
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'noshow':
      case 'no-show':
        return const AppointmentStatusStyle(
          label: 'MISSED',
          description: 'This consultation was missed',
          background: Color(0xFFF1F5F9),
          foreground: Color(0xFF475569),
        );
      case 'cancelled':
      case 'canceled':
        return const AppointmentStatusStyle(
          label: 'CANCELLED',
          description: 'This consultation was cancelled',
          background: PhiaColors.pulseRedLight,
          foreground: Color(0xFFB91C1C),
        );
    }

    if (isPast) {
      return const AppointmentStatusStyle(
        label: 'PAST',
        description: 'The appointment time has passed',
        background: Color(0xFFF1F5F9),
        foreground: Color(0xFF475569),
      );
    }

    switch ((status ?? '').toLowerCase()) {
      case 'confirmed':
        return const AppointmentStatusStyle(
          label: 'CONFIRMED',
          description: 'Confirmed by the doctor',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'booked':
        return const AppointmentStatusStyle(
          label: 'BOOKED',
          description: 'Your time slot is booked',
          background: Color(0xFFE0F2FE),
          foreground: Color(0xFF075985),
        );
      case 'rescheduled':
        return const AppointmentStatusStyle(
          label: 'RESCHEDULED',
          description: 'Moved to a new time',
          background: Color(0xFFEDE9FE),
          foreground: Color(0xFF5B21B6),
        );
      default:
        return const AppointmentStatusStyle(
          label: 'PENDING',
          description: 'Awaiting doctor confirmation',
          background: Color(0xFFFEF3C7),
          foreground: Color(0xFF92400E),
        );
    }
  }
}
