import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../../viewmodel/settings_viewmodel.dart';

void showNotificationCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return const NotificationCenterModal();
    },
  );
}

class NotificationCenterModal extends StatefulWidget {
  const NotificationCenterModal({super.key});

  @override
  State<NotificationCenterModal> createState() => _NotificationCenterModalState();
}

class _NotificationCenterModalState extends State<NotificationCenterModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().fetchInAppNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final inAppLogs = settingsVM.inAppNotificationsList;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PhiaColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PhiaColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: PhiaColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Alerts & Notifications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: PhiaColors.navyAnchor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: PhiaColors.borderSubtle),

          // Alerts content directly
          Expanded(
            child: _buildAlertsSection(context, settingsVM, inAppLogs),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, SettingsViewModel settingsVM, List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No Alerts Yet',
        description: 'Vitals warning alerts or activity milestone achievements will appear here.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${logs.length} ${logs.length == 1 ? 'Alert' : 'Alerts'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PhiaColors.textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: () => settingsVM.clearAllInAppNotifications(),
                icon: const Icon(Icons.delete_sweep_rounded, color: PhiaColors.pulseRed, size: 16),
                label: Text(
                  'Clear All',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PhiaColors.pulseRed),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final String id = log['id'] as String;
              final String title = log['title'] as String;
              final String body = log['body'] as String;
              final String type = log['type'] as String;
              final String timeStr = log['timestamp'] as String;
              final bool isRead = (log['is_read'] as int? ?? 0) == 1;

              String formattedTime = '';
              try {
                final date = DateTime.parse(timeStr).toLocal();
                formattedTime = DateFormat('MMM d, h:mm a').format(date);
              } catch (_) {
                formattedTime = timeStr;
              }

              final Color accentColor = type == 'MILESTONE' ? PhiaColors.stepGreen : PhiaColors.pulseRed;

              return Dismissible(
                key: Key(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: PhiaColors.pulseRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: PhiaColors.pulseRed),
                ),
                onDismissed: (dir) => settingsVM.deleteInAppNotification(id),
                child: GestureDetector(
                  onTap: () {
                    if (!isRead) {
                      settingsVM.markNotificationAsRead(id);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead ? PhiaColors.surface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRead ? PhiaColors.borderSubtle : accentColor.withValues(alpha: 0.35),
                        width: isRead ? 1 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type == 'MILESTONE' ? Icons.emoji_events_rounded : Icons.warning_amber_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    type.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: PhiaColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: PhiaColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: PhiaColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PhiaColors.navyAnchor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: PhiaColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
