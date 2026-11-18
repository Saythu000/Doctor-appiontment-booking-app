import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';

/// Placeholder names and specialties that older builds stored when the real
/// value was unknown. They are treated as "unknown", never shown.
const _placeholderNames = {'attending specialist', 'clinical specialist', 'drgodly specialist'};
const _placeholderRoles = {'specialist care', 'general practice', 'general practitioner'};

/// The doctor's real name, or "Doctor" when the server sent none.
String doctorDisplayName(PractitionerRoleBooking pr) {
  final full = pr.practitionerDetail?.fullName.trim() ?? '';
  if (full.isNotEmpty && !_placeholderNames.contains(full.toLowerCase())) return full;
  final display = pr.practitionerDisplay?.trim() ?? '';
  if (display.isNotEmpty) return display;
  return 'Doctor';
}

/// First specialty from the server, cleaned, or '' when there is none.
String doctorSpecialty(PractitionerRoleBooking pr) =>
    pr.specialties.isEmpty ? '' : BookingViewModel.cleanSpecialty(pr.specialties.first);

/// All cleaned specialties of a doctor.
Iterable<String> doctorSpecialties(PractitionerRoleBooking pr) =>
    pr.specialties.map(BookingViewModel.cleanSpecialty).where((s) => s.isNotEmpty);

/// A role string from route args or storage, with old placeholders removed.
String honestRole(String? role) {
  final r = role?.trim() ?? '';
  return _placeholderRoles.contains(r.toLowerCase()) ? '' : r;
}

/// A name from route args or storage, with old placeholders removed.
String honestName(String? name) {
  final n = name?.trim() ?? '';
  return n.isEmpty || _placeholderNames.contains(n.toLowerCase()) ? 'Your doctor' : n;
}

const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = {
  'mon': 'Mon',
  'tue': 'Tue',
  'wed': 'Wed',
  'thu': 'Thu',
  'fri': 'Fri',
  'sat': 'Sat',
  'sun': 'Sun',
};

/// Weekday codes ("mon".."sun") the doctor works, from their availability.
/// Empty means the server did not say.
Set<String> availableDayCodes(PractitionerRoleBooking? pr) {
  final days = <String>{};
  if (pr == null) return days;
  for (final a in pr.availability) {
    for (final t in a.availableTimes) {
      for (final d in t.daysOfWeek) {
        final code = d.toLowerCase().trim();
        if (code.length >= 3) days.add(code.substring(0, 3));
      }
    }
  }
  return days;
}

String _formatTimePart(String timeStr) {
  final parts = timeStr.trim().split(':');
  if (parts.isEmpty) return timeStr;
  final hour = int.tryParse(parts[0]);
  if (hour == null) return timeStr;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final period = hour >= 12 ? 'PM' : 'AM';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final minStr = minute.toString().padLeft(2, '0');
  return '$h:$minStr $period';
}

String? _availableHoursString(PractitionerRoleBooking pr) {
  for (final a in pr.availability) {
    for (final t in a.availableTimes) {
      final start = t.availableStartTime?.trim();
      final end = t.availableEndTime?.trim();
      if ((start != null && start.isNotEmpty) || (end != null && end.isNotEmpty)) {
        if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
          return '${_formatTimePart(start)}–${_formatTimePart(end)}';
        } else if (start != null && start.isNotEmpty) {
          return _formatTimePart(start);
        } else {
          return _formatTimePart(end!);
        }
      }
    }
  }
  return null;
}

String _formatDayRange(Set<String> days) {
  final indices = <int>[];
  for (int i = 0; i < _dayOrder.length; i++) {
    if (days.contains(_dayOrder[i])) {
      indices.add(i);
    }
  }
  if (indices.isEmpty) return '';
  if (indices.length == 1) {
    return _dayLabels[_dayOrder[indices.first]]!;
  }
  // Check if contiguous range
  bool isContiguous = true;
  for (int i = 0; i < indices.length - 1; i++) {
    if (indices[i + 1] != indices[i] + 1) {
      isContiguous = false;
      break;
    }
  }
  if (isContiguous) {
    return '${_dayLabels[_dayOrder[indices.first]]}–${_dayLabels[_dayOrder[indices.last]]}';
  }
  return indices.map((i) => _dayLabels[_dayOrder[i]]!).join(', ');
}

/// "Mon–Fri · 9:00 AM–5:00 PM" or "Mon–Sun · 9:00 AM–10:00 PM", or days only when hours unknown, or null when unknown.
String? availabilityLabel(PractitionerRoleBooking pr) {
  final days = availableDayCodes(pr);
  if (days.isEmpty) return null;
  final daysText = _formatDayRange(days);
  if (daysText.isEmpty) return null;
  final hours = _availableHoursString(pr);
  if (hours != null && hours.isNotEmpty) {
    return '$daysText · $hours';
  }
  return daysText;
}

/// True when [day] is one of the doctor's working days (or the server did not
/// say which days they work).
bool isDoctorAvailableOn(PractitionerRoleBooking? pr, DateTime day) {
  final days = availableDayCodes(pr);
  if (days.isEmpty) return true;
  return days.contains(_dayOrder[day.weekday - 1]);
}

String _initials(String name) {
  final words = name
      .replaceAll(RegExp(r'^(dr\.?|doctor)\s+', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final first = words.first[0];
  final last = words.length > 1 ? words.last[0] : '';
  return (first + last).toUpperCase();
}

/// Round avatar: the doctor's real photo when there is one, otherwise their
/// initials. Never a stock or placeholder photo.
class DoctorAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const DoctorAvatar({super.key, required this.name, this.photoUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = _initials(name);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.5, color: colors.onPrimaryContainer)
          : Text(
              initials,
              textScaler: TextScaler.noScaling, // fixed-size circle
              style: context.text.titleMedium!.copyWith(
                color: colors.onPrimaryContainer,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    final url = photoUrl?.trim() ?? '';
    final Widget child;
    if (url.startsWith('http')) {
      final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
      child = ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          cacheWidth: px,
          fit: BoxFit.cover,
          loadingBuilder: (context, img, progress) => progress == null ? img : fallback,
          errorBuilder: (context, error, stack) => fallback,
        ),
      );
    } else {
      // Bundled stock photos used by older builds are not real: show initials.
      child = fallback;
    }
    return ExcludeSemantics(child: SizedBox(width: size, height: size, child: child));
  }
}

/// Icon + label + value row used in booking summaries.
class SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const SummaryRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: AppRadius.smAll),
              child: Icon(icon, size: AppSizes.iconMd, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.bodySmall),
                  Text(value, style: context.text.titleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar, name and (when known) specialty, side by side.
class DoctorHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;
  final double avatarSize;

  const DoctorHeader({super.key, required this.name, required this.role, this.photoUrl, this.avatarSize = 56});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DoctorAvatar(name: name, photoUrl: photoUrl, size: avatarSize),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.text.titleMedium),
              if (role.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(role, style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
