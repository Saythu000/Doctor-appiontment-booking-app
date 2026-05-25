import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _selectedMissionIndex = -1;

  final List<Map<String, dynamic>> _missions = [
    {
      'id': '01',
      'title': 'BUILD STRENGTH',
      'desc': 'Prioritize hypertrophy and functional power.',
      'icon': Icons.fitness_center,
    },
    {
      'id': '02',
      'title': 'INCREASE ENDURANCE',
      'desc': 'Optimize cardiovascular health and stamina.',
      'icon': Icons.speed,
    },
    {
      'id': '03',
      'title': 'OPTIMIZE RECOVERY',
      'desc': 'Focus on mobility, sleep, and longevity.',
      'icon': Icons.self_improvement,
    },
    {
      'id': '04',
      'title': 'ELITE PERFORMANCE',
      'desc': 'Push the limits of human biometric potential.',
      'icon': Icons.trending_up,
    },
  ];

  Widget _buildMissionCard(int index) {
    final mission = _missions[index];
    final isSelected = _selectedMissionIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMissionIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission['id'],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black54 : Colors.white38,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission['title'],
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: isSelected ? Colors.black : Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mission['desc'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected ? Colors.black87 : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              mission['icon'] as IconData,
              color: isSelected ? Colors.black : Colors.white54,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix texture background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bolt, color: Colors.white, size: 24),
                      onPressed: () {},
                    ),
                    Text(
                      'PHIA',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 24,
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main scrolling view
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 80.0, bottom: 180.0, left: 24.0, right: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'STEP 01 / 04',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title Text
                  Text(
                    'WHAT IS YOUR MISSION?',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 24),

                  // List of bento cards
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _missions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildMissionCard(index),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/complete');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/complete');
                    },
                    child: Text(
                      'SKIP FOR NOW',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
