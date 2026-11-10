import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/brand.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/home/presentation/widgets/body_baseline_card.dart';
import 'package:phia_flutter/features/home/presentation/widgets/next_appointment_card.dart';
import 'package:phia_flutter/features/home/presentation/widgets/prepare_visit_card.dart';
import 'package:phia_flutter/features/home/presentation/widgets/vitals_summary_card.dart';
import 'package:phia_flutter/features/notifications/presentation/notification_center_sheet.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/device_manager_sheet.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/sync_status_strip.dart';
import 'package:provider/provider.dart';

/// Home: the next visit first, then getting ready for it, then today's
/// health at a glance.
class DashboardScreen extends StatelessWidget {
  /// Switches the bottom-navigation tab (1 = Vitals, 2 = Doctors).
  final void Function(int)? onTabSelected;
  const DashboardScreen({super.key, this.onTabSelected});

  static const int vitalsTab = 1;
  static const int doctorsTab = 2;

  String _firstName(BuildContext context) {
    final profile = context.watch<ProfileViewModel>().currentProfile;
    final names = profile?.name;
    if (names != null && names.isNotEmpty && names.first.givenName.trim().isNotEmpty) {
      return names.first.givenName.trim();
    }
    final authName = context.watch<AuthViewModel>().user?.name.trim() ?? '';
    return authName.isEmpty ? '' : authName.split(' ').first;
  }

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(BuildContext context) async {
    final activity = context.read<ActivityViewModel>();
    final profile = context.read<ProfileViewModel>();
    final booking = context.read<BookingViewModel>();
    await Future.wait([
      activity.syncOpenWearablesVitals('Android Health Connect').then((_) => activity.initDashboard()),
      profile.fetchOrInitProfile(),
      booking.fetchAppointments(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = context.watch<BookingViewModel>();
    final next = findNextAppointment(booking.appointmentsList);
    final now = DateTime.now();
    final name = _firstName(context);

    var i = 0;
    Widget enter(Widget child) => FadeSlideIn(delay: Duration(milliseconds: 50 * i++), child: child);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: const BrandHeader(markSize: 30),
        actions: const [_AlertsButton(), SizedBox(width: AppSpacing.xs)],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        // A short, fixed set of cards: built once so the entrance stagger
        // plays once, not again for each card scrolled into view.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              enter(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(name.isEmpty ? _greeting(now) : '${_greeting(now)}, $name',
                          style: context.text.headlineSmall),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      DateFormat('EEEE, d MMMM').format(now),
                      style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (booking.appointmentsError != null) ...[
                _StaleNote(onRetry: () => context.read<BookingViewModel>().fetchAppointments()),
                const SizedBox(height: AppSpacing.sm),
              ],
              enter(NextAppointmentCard(appointment: next, onBook: () => onTabSelected?.call(doctorsTab))),
              const SizedBox(height: AppSpacing.lg),
              enter(const PrepareVisitCard()),
              const SizedBox(height: AppSpacing.xl),
              enter(SyncStatusStrip(onManage: () => DeviceManagerSheet.show(context))),
              const SizedBox(height: AppSpacing.sm),
              enter(VitalsSummaryCard(onOpen: () => onTabSelected?.call(vitalsTab))),
              const SizedBox(height: AppSpacing.lg),
              enter(const BodyBaselineCard()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your visits may be out of date" with a Retry, shown when the last
/// appointments refresh failed and the saved list is on screen.
class _StaleNote extends StatelessWidget {
  final VoidCallback onRetry;
  const _StaleNote({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.tone(StatusTone.warning);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.mdAll),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: AppSizes.iconSm, color: tone.foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Your visits may be out of date.',
                style: context.text.labelMedium!.copyWith(color: tone.foreground),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: tone.foreground),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsButton extends StatelessWidget {
  const _AlertsButton();

  @override
  Widget build(BuildContext context) {
    final unread =
        context.watch<SettingsViewModel>().inAppNotificationsList.where((n) => (n['is_read'] ?? 0) == 0).length;
    return IconButton(
      onPressed: () => showNotificationCenter(context),
      tooltip: unread > 0 ? 'Alerts, $unread unread' : 'Alerts',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
