import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'dashboard_screen.dart';
import '../booking/select_specialist_screen.dart';
import '../workout/workout_library_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

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
      const WorkoutLibraryScreen(),
      const ProfileScreen(isTab: true),
    ];

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 3)
          ? Container(
              margin: const EdgeInsets.only(bottom: 8, right: 8),
              width: 58,
              height: 58,
              child: FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/assistant'),
                backgroundColor: Colors.black,
                elevation: 4,
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            )
          : null,
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
                icon: Icons.bolt_outlined,
              ),
              _buildNavItem(
                index: 3,
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
