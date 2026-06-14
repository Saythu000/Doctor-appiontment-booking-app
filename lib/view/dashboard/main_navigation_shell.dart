import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/activity_viewmodel.dart';
import 'dashboard_screen.dart';
import '../booking/select_specialist_screen.dart';
import '../profile/profile_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ActivityViewModel>(context, listen: false).requestHardwarePermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const SelectSpecialistScreen(isTab: true),
      const ProfileScreen(isTab: true),
    ];

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          color: PhiaColors.background,
          border: Border(
            top: BorderSide(
              color: PhiaColors.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.crop_landscape_outlined,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.calendar_today_outlined,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    bool isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // White dash indicator above the active icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
