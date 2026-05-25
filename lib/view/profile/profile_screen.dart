import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix Background Grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (⚡ KINETIC and Notification Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'KINETIC',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 16),

                      // 1. AVATAR BLOCK
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Double circle athlete avatar frame
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 2.0,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: NetworkImage('https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=500'),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.matrix(<double>[
                                          0.2126, 0.7152, 0.0722, 0, -20,
                                          0.2126, 0.7152, 0.0722, 0, -20,
                                          0.2126, 0.7152, 0.0722, 0, -20,
                                          0,      0,      0,      1, 0,
                                        ]),
                                      ),
                                    ),
                                  ),
                                ),
                                // ELITE Overlaid pill tag at the bottom
                                Positioned(
                                  bottom: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'ELITE',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            // User Name
                            Text(
                              'ALEX RIVERS',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Calibration ID
                            Text(
                              'KNTC-0924-XR',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.38),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 2. PERFORMANCE STATS CARD (3 Columns)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            _buildStatItem('WORKOUTS', '142'),
                            _buildVerticalDivider(),
                            _buildStatItem('HOURS', '84H'),
                            _buildVerticalDivider(),
                            _buildStatItem('PBS', '12'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 3. SETTINGS LIST BENTO BOX
                      Container(
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            _buildSettingsTile(
                              icon: Icons.emoji_events_outlined,
                              title: 'Personal Records',
                            ),
                            _buildHorizontalDivider(),
                            _buildSettingsTile(
                              icon: Icons.history,
                              title: 'Training History',
                            ),
                            _buildHorizontalDivider(),
                            // Connected Devices tile with sub grey outline chips
                            _buildSettingsTile(
                              icon: Icons.watch_outlined,
                              title: 'Connected Devices',
                              subContent: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    _buildOutlineChip('APPLE WATCH'),
                                    const SizedBox(width: 8),
                                    _buildOutlineChip('CHEST STRAP'),
                                  ],
                                ),
                              ),
                            ),
                            _buildHorizontalDivider(),
                            // Activity tracking screen navigation tile
                            _buildSettingsTile(
                              icon: Icons.bar_chart_outlined,
                              title: 'Activity',
                              subContent: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'Weekly steps, calories & analytics',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.38),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/activity_tracking');
                              },
                            ),
                            _buildHorizontalDivider(),
                            // Subscription Plan tile with Kinetic Pro subtext
                            _buildSettingsTile(
                              icon: Icons.card_membership_outlined,
                              title: 'Subscription Plan',
                              subContent: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'Kinetic Pro',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.38),
                                  ),
                                ),
                              ),
                            ),
                            _buildHorizontalDivider(),
                            _buildSettingsTile(
                              icon: Icons.settings_outlined,
                              title: 'App Settings',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 4. LOG OUT ACCOUNT OUTLINED BUTTON
                      GestureDetector(
                        onTap: () {
                          // Simple return to login state
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Center(
                            child: Text(
                              'LOG OUT ACCOUNT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Stat item helper
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Divider helpers
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildHorizontalDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // Outline capsule chip helper
  Widget _buildOutlineChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Premium list settings tile builder
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? subContent,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (subContent != null) subContent,
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.24),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
