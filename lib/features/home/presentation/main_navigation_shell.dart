import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/features/booking/presentation/select_specialist_screen.dart';
import 'package:phia_flutter/features/home/presentation/dashboard_screen.dart';
import 'package:phia_flutter/features/profile/presentation/profile_screen.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/vitals_screen.dart';
import 'package:provider/provider.dart';

/// The signed-in app: four tabs with a Material 3 navigation bar.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Ask for notification and Health Connect access once, after the first
    // frame so the home screen is already visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActivityViewModel>().requestHardwarePermissions();
    });
  }

  void _select(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    // Android back on another tab returns to Home; only back on Home leaves
    // the app (standard bottom-navigation behaviour).
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(onTabSelected: _select),
            const VitalsScreen(isTab: true),
            const SelectSpecialistScreen(isTab: true),
            const ProfileScreen(isTab: true),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart_rounded),
              label: 'Vitals',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_services_outlined),
              selectedIcon: Icon(Icons.medical_services_rounded),
              label: 'Doctors',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
