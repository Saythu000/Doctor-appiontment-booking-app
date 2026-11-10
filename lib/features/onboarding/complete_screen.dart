import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:phia_flutter/features/onboarding/widgets/success_check.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:provider/provider.dart';

/// Onboarding step 3: confirmation and what to do next.
class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key});

  static const _nextSteps = [
    (Icons.video_camera_front_rounded, 'Book a doctor', 'Find a doctor and pick a time from the Doctors tab.'),
    (Icons.forum_rounded, 'Prepare for your visit', 'Tell us your symptoms by chat or voice before you see the doctor.'),
    (Icons.watch_rounded, 'Connect your watch', 'Bring in heart rate, steps and sleep through Health Connect.'),
  ];

  @override
  Widget build(BuildContext context) {
    final given = context.watch<ProfileViewModel>().currentProfile?.name?.firstOrNull?.givenName.trim() ?? '';
    final colors = context.colors;

    return PopScope(
      // Setup is finished: back must not reopen the forms.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: OnboardingScaffold(
        step: 3,
        hero: const SuccessCheck(),
        title: given.isEmpty ? "You're all set" : "You're all set, $given",
        subtitle: 'Your profile is ready. Here is what you can do next.',
        bottom: AppButton(label: 'Go to Home', onPressed: () => context.go(AppRoutes.home)),
        child: Column(
          children: [
            for (var i = 0; i < _nextSteps.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 300 + 80 * i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: AppRadius.mdAll),
                        child: Icon(_nextSteps[i].$1, color: colors.primary, size: AppSizes.iconMd),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_nextSteps[i].$2, style: context.text.titleSmall),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(_nextSteps[i].$3, style: context.text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
