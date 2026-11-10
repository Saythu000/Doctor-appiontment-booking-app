import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';

/// Gender values as onboarding stores them; the server may return lowercase.
const profileGenders = [('MALE', 'Male'), ('FEMALE', 'Female'), ('OTHER', 'Other')];

String genderLabel(String? gender) {
  final g = gender?.trim().toUpperCase() ?? '';
  for (final (value, label) in profileGenders) {
    if (value == g) return label;
  }
  return g.isEmpty ? 'Not set' : '${g[0]}${g.substring(1).toLowerCase()}';
}

/// "1990-04-12" -> "12 Apr 1990 (36 years)". "Not set" when unknown.
String birthDateLabel(String? birthDate, {DateTime? today}) {
  final dob = DateTime.tryParse(birthDate ?? '');
  if (dob == null) return 'Not set';
  final now = today ?? DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
  final date = DateFormat('d MMM y').format(dob);
  return age >= 0 ? '$date ($age years)' : date;
}

String addressLabel(PlainPatient profile) {
  final a = (profile.address?.isNotEmpty ?? false) ? profile.address!.first : null;
  if (a == null) return 'Not set';
  final parts = [
    ...a.line,
    a.city,
    a.state,
    a.postalCode,
    a.country,
  ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? 'Not set' : parts.join(', ');
}

/// "Personal details" card on the profile tab. Shows only real data:
/// anything unknown reads "Not set".
class ProfileDetailsCard extends StatelessWidget {
  final PlainPatient profile;
  final VoidCallback onEdit;

  const ProfileDetailsCard({super.key, required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    String orNotSet(String v) => v.trim().isEmpty ? 'Not set' : v.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Personal details', actionLabel: 'Edit', onAction: onEdit),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(icon: Icons.cake_outlined, label: 'Date of birth', value: birthDateLabel(profile.birthDate)),
              _DetailRow(icon: Icons.wc_rounded, label: 'Gender', value: genderLabel(profile.gender)),
              _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: orNotSet(profile.primaryPhone)),
              _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: orNotSet(profile.primaryEmail)),
              _DetailRow(icon: Icons.home_outlined, label: 'Address', value: addressLabel(profile)),
              if (profile.id > 0)
                _DetailRow(icon: Icons.badge_outlined, label: 'Patient ID', value: '#${profile.id}', last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _DetailRow({required this.icon, required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notSet = value == 'Not set';
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppSizes.iconMd, color: colors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.bodySmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    style: context.text.bodyLarge!.copyWith(
                      color: notSet ? colors.textMuted : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
