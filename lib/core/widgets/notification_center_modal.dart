import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';

void showNotificationCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D0E0F),
    shape: const Border(
      top: BorderSide(color: Colors.white12, width: 1.0),
    ),
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

class _NotificationCenterModalState extends State<NotificationCenterModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Fetch latest notification log from database on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().fetchInAppNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final bookingVM = context.watch<BookingViewModel>();

    final inAppLogs = settingsVM.inAppNotificationsList;
    final appointments = bookingVM.appointmentsList.where((appt) {
      try {
        final startTime = DateTime.parse(appt['start_time'] as String);
        return startTime.isAfter(DateTime.now());
      } catch (_) {
        return false;
      }
    }).toList();
    
    final activeReminders = settingsVM.remindersList.where((r) => (r['is_active'] as int) == 1).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: PhiaColors.skyBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'NOTIFICATION CENTER',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab header
          TabBar(
            controller: _tabController,
            indicatorColor: PhiaColors.skyBlue,
            labelColor: PhiaColors.skyBlue,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            dividerColor: Colors.white.withValues(alpha: 0.08),
            tabs: const [
              Tab(text: 'ALERTS & MILESTONES'),
              Tab(text: 'VISITS SCHEDULE'),
              Tab(text: 'DAILY ALARMS'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Alerts & Milestones logs
                _buildAlertsSection(context, settingsVM, inAppLogs),

                // 2. Upcoming appointment visits
                _buildVisitsSection(context, appointments),

                // 3. Active Meds/Vitals reminders
                _buildRemindersSection(context, activeReminders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, SettingsViewModel settingsVM, List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none,
        title: 'NO TELEMETRY ALERTS YET',
        description: 'Vitals warning anomalies or milestone steps completions will log here.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => settingsVM.clearAllInAppNotifications(),
                icon: const Icon(Icons.delete_sweep, color: PhiaColors.pulseRed, size: 16),
                label: Text(
                  'CLEAR LOGS',
                  style: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 1.0, color: PhiaColors.pulseRed),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
                      color: isRead ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
                      border: Border.all(
                        color: isRead ? Colors.white.withValues(alpha: 0.08) : accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          type == 'MILESTONE' ? Icons.emoji_events_outlined : Icons.warning_amber_outlined,
                          color: accentColor,
                          size: 20,
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
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
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

  Widget _buildVisitsSection(BuildContext context, List<Map<String, dynamic>> appointments) {
    if (appointments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'NO UPCOMING APPOINTMENTS',
        description: 'Schedule a virtual consultation or in-person checkup to receive countdown reminders.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        final name = appt['practitioner_name'] as String;
        final role = appt['practitioner_role'] as String;
        final startTimeStr = appt['start_time'] as String;
        final type = appt['type'] as String;

        String formattedDate = '';
        try {
          final dt = DateTime.parse(startTimeStr).toLocal();
          formattedDate = DateFormat('EEEE, MMMM d @ h:mm a').format(dt).toUpperCase();
        } catch (_) {
          formattedDate = startTimeStr;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PhiaColors.surface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medical_services_outlined, color: PhiaColors.skyBlue, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: PhiaColors.skyBlue,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      role,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 14,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemindersSection(BuildContext context, List<Map<String, dynamic>> reminders) {
    if (reminders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.alarm_off,
        title: 'NO SCHEDULERS ACTIVE',
        description: 'Enable medication doses or vital signs check reminders inside profile configuration.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final rem = reminders[index];
        final title = rem['title'] as String;
        final type = rem['type'] as String;
        final time = rem['time'] as String;
        final days = rem['days'] as String;

        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final timeOfDay = TimeOfDay(hour: hour, minute: minute);
        final formattedTime = timeOfDay.format(context);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                type == 'Medication' ? Icons.bubble_chart_outlined : Icons.favorite_border_outlined,
                color: PhiaColors.stepGreen,
                size: 20,
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
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: PhiaColors.stepGreen,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          days,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedTime,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 20,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            Icon(icon, size: 48, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.bebasNeue(
                fontSize: 16,
                color: Colors.white38,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white24,
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
