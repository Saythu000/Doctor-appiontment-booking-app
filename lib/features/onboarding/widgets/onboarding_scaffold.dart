import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/brand.dart';
import 'package:phia_flutter/core/widgets/motion.dart';

/// Number of onboarding steps (profile, focus areas, all set).
const int kOnboardingSteps = 3;

/// Shared layout for the onboarding steps: brand + step progress at the top,
/// scrollable content, and the actions pinned at the bottom.
class OnboardingScaffold extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget bottom;
  final bool showBack;

  /// Optional illustration above the title (for example a success check).
  final Widget? hero;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.bottom,
    this.showBack = false,
    this.hero,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: AppSpacing.sm),
                    const Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandHeader(markSize: 28))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: OnboardingProgress(step: step),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hero != null) ...[Center(child: hero), const SizedBox(height: AppSpacing.xl)],
                      FadeSlideIn(
                        child: Semantics(header: true, child: Text(title, style: context.text.headlineSmall)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 60),
                        child: Text(subtitle, style: context.text.bodyMedium),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeSlideIn(delay: const Duration(milliseconds: 120), child: child),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                  child: bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Step 2 of 3" label with a bar that animates from the previous step.
class OnboardingProgress extends StatelessWidget {
  final int step;
  const OnboardingProgress({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = step / kOnboardingSteps;
    final from = (step - 1) / kOnboardingSteps;
    return Semantics(
      label: 'Step $step of $kOnboardingSteps',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step $step of $kOnboardingSteps', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: AppMotion.reduced(context) ? target : from, end: target),
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            builder: (context, value, _) => ClipRRect(
              borderRadius: AppRadius.smAll,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.surfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
