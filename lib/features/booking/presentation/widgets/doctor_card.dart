import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';

/// One doctor in the list: photo or initials, name, specialty (when known),
/// working days (when known) and a Book button.
class DoctorCard extends StatelessWidget {
  final PractitionerRoleBooking doctor;
  final VoidCallback onBook;

  const DoctorCard({super.key, required this.doctor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = doctorDisplayName(doctor);
    final specialty = doctorSpecialty(doctor);
    final days = availabilityLabel(doctor);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DoctorHeader(name: name, role: specialty, photoUrl: doctor.practitionerDetail?.photoUrl),
          if (days != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.event_available_rounded, size: AppSizes.iconSm, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Available $days',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Book a visit with $name',
              excludeSemantics: true,
              child: AppButton(label: 'Book', icon: Icons.event_rounded, expand: false, onPressed: onBook),
            ),
          ),
        ],
      ),
    );
  }
}
