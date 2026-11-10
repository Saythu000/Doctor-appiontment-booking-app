import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../data/service/open_wearables_service.dart';
import '../../viewmodel/activity_viewmodel.dart';

class DeviceManagerSheet extends StatefulWidget {
  const DeviceManagerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DeviceManagerSheet(),
    );
  }

  @override
  State<DeviceManagerSheet> createState() => _DeviceManagerSheetState();
}

class _DeviceManagerSheetState extends State<DeviceManagerSheet> {
  final OpenWearablesService _owService = OpenWearablesService();
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.watch_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect Wearables',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyAnchor,
                        ),
                      ),
                      Text(
                        'Sync from Android Health Connect',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Expanded(child: _buildHealthConnectContent(context)),

          // Where the data goes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.activeGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Synced readings are saved to your DrGodly health record.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectContent(BuildContext context) {
    final activityVm = context.watch<ActivityViewModel>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Hero Card: Android Health Connect
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activityVm.isOpenWearablesSynced
                  ? AppColors.activeGreen
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded,
                        color: Color(0xFF34A853), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Android Health Connect',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navyAnchor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (activityVm.isOpenWearablesSynced)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.activeGreen, size: 16),
                          ],
                        ),
                        Text(
                          'Works with any watch that syncs to Health Connect',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Reads heart rate, HRV, steps, sleep and SpO2 that your watch app (for example boAt Crest, Noise or Samsung Health) writes to Health Connect.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Read-only access',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyAnchor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      _isSyncing
                          ? 'Syncing...'
                          : (activityVm.isOpenWearablesSynced
                              ? 'Sync Again'
                              : 'Sync Now'),
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed:
                        _isSyncing ? null : () => _syncHealthConnect(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Asks for Health Connect access (no UI if already granted), then syncs.
  Future<void> _syncHealthConnect(BuildContext context) async {
    final vm = Provider.of<ActivityViewModel>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSyncing = true);
    bool granted = false;
    bool success = false;
    try {
      granted = await vm.requestHealthConnectAuthorization();
      if (granted) {
        success = await vm.syncOpenWearablesVitals('Android Health Connect');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
    if (!mounted) return;

    final String message;
    final Color color;
    if (!granted) {
      message =
          'Health Connect access was not granted. Allow access in Health Connect to sync your watch data.';
      color = const Color(0xFFB45309);
    } else if (success) {
      final hr = vm.dashboardHr.toInt();
      message = hr > 0
          ? 'Watch data synced. Resting HR: $hr bpm from ${_owService.lastSyncSource}.'
          : 'Watch data synced from ${_owService.lastSyncSource}.';
      color = AppColors.activeGreen;
    } else {
      message =
          'No recent watch data in Health Connect. Open your watch app, let it sync to Health Connect, then try again.';
      color = const Color(0xFFB45309);
    }
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        content: Text(
          message,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }
}
