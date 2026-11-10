import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/auth/presentation/session_reset.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/edit_profile_page.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/profile_header.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/widgets/settings_tile.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// The Profile tab (and page): who you are, your health settings, sign out.
class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileViewModel>().fetchOrInitProfile();
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to see your health data.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await signOutAndResetSession(context);
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      showAppMessage(context, "Couldn't sign out. Please try again.", type: FeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthViewModel>().user;
    final profileVM = context.watch<ProfileViewModel>();
    final appointments = context.watch<BookingViewModel>().appointmentsList.length;
    final activity = context.watch<ActivityViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final activeReminders = settings.remindersList.where((r) => r['is_active'] == 1).length;
    final profile = profileVM.currentProfile;

    final profileName = (profile?.name?.isNotEmpty ?? false) ? profile!.name!.first.fullName.trim() : '';
    final name = profileName.isNotEmpty ? profileName : (authUser?.name.trim() ?? '');
    final email = (profile?.primaryEmail.isNotEmpty ?? false) ? profile!.primaryEmail : (authUser?.email ?? '');
    final contact = email.isNotEmpty ? email : (profile?.primaryPhone ?? '');

    final heightWeight = activity.userHeight <= 0 && activity.userWeight <= 0
        ? 'Not set'
        : '${settings.formatHeight(activity.userHeight)} · ${settings.formatWeight(activity.userWeight)}';

    Widget details;
    if (profile != null) {
      details = ProfileDetailsCard(profile: profile, onEdit: () => openEditProfile(context));
    } else if (profileVM.isProfileLoading) {
      details = const SizedBox(height: 160, child: LoadingView(message: 'Loading your profile…'));
    } else {
      details = AppCard(
        child: EmptyView(
          icon: Icons.assignment_ind_outlined,
          title: 'Complete your profile',
          message: 'Add your details so your care team knows who you are.',
          actionLabel: 'Complete profile',
          onAction: () => context.push(AppRoutes.profileSetup),
        ),
      );
    }

    final sections = <Widget>[
      ProfileHeader(name: name, contact: contact, imagePath: profileVM.profileImagePath),
      details,
      SettingsGroup(
        title: 'Health',
        children: [
          SettingsTile(
            icon: Icons.monitor_weight_outlined,
            title: 'Height & weight',
            value: heightWeight,
            onTap: () => context.push(AppRoutes.generalSettings),
          ),
          SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Reminders',
            value: activeReminders == 0 ? 'None on' : '$activeReminders on',
            onTap: () => context.push(AppRoutes.reminders),
          ),
          SettingsTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Vital alert limits',
            value: 'Heart rate, blood pressure, steps',
            onTap: () => context.push(AppRoutes.alertLimits),
          ),
          SettingsTile(
            icon: Icons.straighten_rounded,
            title: 'Units',
            value: '${settings.usesPounds ? 'lb' : 'kg'} · ${settings.usesFeetInches ? 'ft & in' : 'cm'}',
            onTap: () => context.push(AppRoutes.units),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Account',
        children: [
          SettingsTile(
            icon: Icons.event_note_outlined,
            title: 'Appointments',
            value: appointments == 0 ? 'None yet' : '$appointments',
            onTap: () => context.push(AppRoutes.appointments),
          ),
        ],
      ),
      AppButton.secondary(
        label: 'Sign out',
        icon: Icons.logout_rounded,
        isLoading: _signingOut,
        onPressed: _signOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: !widget.isTab,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ProfileViewModel>().fetchOrInitProfile(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
            itemCount: sections.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xl),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Duration(milliseconds: 50 * i),
              child: sections[i],
            ),
          ),
        ),
      ),
    );
  }
}
