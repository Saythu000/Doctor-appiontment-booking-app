import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/onboarding/widgets/goal_card.dart';
import 'package:phia_flutter/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:provider/provider.dart';

/// Onboarding step 2: what the patient wants to use DrGodly for.
/// The choice is saved (setting `focus_areas`); nothing is preselected.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _Goal {
  final IconData icon;
  final String title;
  final String description;
  const _Goal(this.icon, this.title, this.description);
}

const _goals = [
  _Goal(Icons.video_camera_front_rounded, 'See doctors', 'Book video or in-person visits with verified doctors.'),
  _Goal(Icons.forum_rounded, 'Prepare for visits', 'Answer pre-visit questions by chat or voice.'),
  _Goal(Icons.monitor_heart_rounded, 'Follow my vitals', 'Heart rate, steps and sleep from your watch via Health Connect.'),
  _Goal(Icons.notifications_active_rounded, 'Reminders and alerts', 'Medicine reminders, and alerts when a reading is outside your limits.'),
];

class _GoalsScreenState extends State<GoalsScreen> {
  final Set<int> _selected = {};
  bool _saving = false;

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    final chosen = (_selected.toList()..sort()).map((i) => _goals[i].title).join('|');
    try {
      await context.read<SettingsViewModel>().saveSetting('focus_areas', chosen);
      if (!mounted) return;
      context.push(AppRoutes.onboardingComplete);
    } catch (_) {
      if (mounted) {
        showAppMessage(context, "Couldn't save your choice. Please try again.", type: FeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      showBack: true,
      title: 'What would you like to do?',
      subtitle: 'Pick any that apply. This helps us understand what matters to you.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Continue',
            isLoading: _saving,
            onPressed: _selected.isEmpty ? null : _continue,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton.text(
            label: 'Skip for now',
            onPressed: _saving ? null : () => context.push(AppRoutes.onboardingComplete),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < _goals.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 * i),
                child: GoalCard(
                  icon: _goals[i].icon,
                  title: _goals[i].title,
                  description: _goals[i].description,
                  selected: _selected.contains(i),
                  onTap: () => setState(() => _selected.contains(i) ? _selected.remove(i) : _selected.add(i)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
