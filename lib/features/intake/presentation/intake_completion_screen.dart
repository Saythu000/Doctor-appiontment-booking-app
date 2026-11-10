import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/intake/domain/intake_models.dart';
import 'package:phia_flutter/features/intake/presentation/widgets/success_check.dart';

/// How the intake was taken.
enum IntakeMode { chat, voice }

/// What the completion screen needs; passed as the route's `extra`.
///
/// The screen shows only what is in here. It never reads the chat or voice
/// view models, so a finished voice call can't show a leftover chat report
/// (or the other way round).
class IntakeCompletionArgs {
  final IntakeMode mode;
  final Map<String, dynamic>? doctorArgs;
  final int? intakeId;
  final IntakeClinicalReport? clinicalReport;
  final int? appointmentId;

  /// Number of messages saved with the intake, when known.
  final int? turnCount;

  const IntakeCompletionArgs({
    required this.mode,
    this.doctorArgs,
    this.intakeId,
    this.clinicalReport,
    this.appointmentId,
    this.turnCount,
  });
}

/// Risk level from the report mapped to a colour family and words.
/// Unknown values stay neutral and show the raw value, never a guess.
({StatusTone tone, String label, IconData icon}) intakeRiskStyle(String risk) {
  switch (risk.trim().toLowerCase()) {
    case 'low':
      return (tone: StatusTone.success, label: 'Low priority', icon: Icons.check_circle_outline_rounded);
    case 'moderate':
    case 'medium':
      return (tone: StatusTone.warning, label: 'Moderate priority', icon: Icons.info_outline_rounded);
    case 'high':
      return (tone: StatusTone.danger, label: 'High priority', icon: Icons.warning_amber_rounded);
    case 'critical':
    case 'urgent':
    case 'emergency':
      return (tone: StatusTone.danger, label: 'Urgent', icon: Icons.warning_amber_rounded);
    default:
      final raw = risk.trim();
      return (
        tone: StatusTone.neutral,
        label: raw.isEmpty ? 'Priority not set' : 'Priority: $raw',
        icon: Icons.help_outline_rounded,
      );
  }
}

class IntakeCompletionScreen extends StatelessWidget {
  final IntakeCompletionArgs args;

  const IntakeCompletionScreen({super.key, required this.args});

  void _book(BuildContext context) {
    final intakeExtra = {
      'intakeCompleted': true,
      'intakeId': args.intakeId,
      'clinicalReport': args.clinicalReport,
    };
    if (args.doctorArgs != null) {
      context.push(AppRoutes.bookingTime, extra: {...args.doctorArgs!, ...intakeExtra});
    } else {
      context.push(AppRoutes.doctors, extra: intakeExtra);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final report = args.clinicalReport;
    final overview = report?.clinicalOverview?.trim();
    final risk = report?.riskLevel;
    final doctorName = args.doctorArgs?['name']?.toString();
    final hasDoctor = args.doctorArgs != null;
    final riskStyle = risk == null ? null : intakeRiskStyle(risk);
    final urgent = riskStyle?.tone == StatusTone.danger;
    final redFlags = _redFlagList(report?.redFlags);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intake saved'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SuccessCheck()),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text('Your answers are saved', style: context.text.headlineSmall, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  args.mode == IntakeMode.voice
                      ? 'Your voice conversation is saved to your profile. Your doctor will see a summary before your visit.'
                      : 'Your chat is saved to your profile. Your doctor will see a summary before your visit.',
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              if (args.intakeId != null || args.turnCount != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  [
                    if (args.intakeId != null) 'Reference number: ${args.intakeId}',
                    if (args.turnCount != null) '${args.turnCount} messages saved',
                  ].join(' · '),
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (overview != null && overview.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Summary for your doctor', style: context.text.titleMedium),
                        ),
                        if (riskStyle != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          StatusBadge(label: riskStyle.label, tone: riskStyle.tone, icon: riskStyle.icon),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(overview, style: context.text.bodyMedium!.copyWith(color: colors.textPrimary)),
                        if (redFlags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('Things your doctor will check', style: context.text.labelLarge),
                          const SizedBox(height: AppSpacing.xs),
                          for (final flag in redFlags)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.flag_outlined, size: 16, color: colors.tone(StatusTone.warning).foreground),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text(flag, style: context.text.bodySmall)),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'The summary is not ready to show here yet. Your answers are saved and your doctor can see them.',
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              if (urgent) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.tone(StatusTone.danger).background,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.local_hospital_outlined, size: 20, color: colors.tone(StatusTone.danger).foreground),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'If you feel very unwell, call your local emergency number now. Do not wait for your appointment.',
                          style: context.text.bodyMedium!.copyWith(color: colors.tone(StatusTone.danger).foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: hasDoctor
                    ? (doctorName != null && doctorName.isNotEmpty
                        ? 'Continue booking with $doctorName'
                        : 'Continue booking')
                    : 'Book a doctor',
                icon: Icons.calendar_month_rounded,
                onPressed: () => _book(context),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Go to Home',
                icon: Icons.home_outlined,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Red flags arrive as a list, a single string, or nothing.
  static List<String> _redFlagList(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }
}
