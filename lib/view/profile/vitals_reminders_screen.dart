import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/settings_viewmodel.dart';
import '../../core/utils/language_helper.dart';

class VitalsRemindersScreen extends StatefulWidget {
  const VitalsRemindersScreen({super.key});

  @override
  State<VitalsRemindersScreen> createState() => _VitalsRemindersScreenState();
}

class _VitalsRemindersScreenState extends State<VitalsRemindersScreen> {
  void _showReminderBottomSheet(BuildContext context, {Map<String, dynamic>? reminder}) {
    final bool isEdit = reminder != null;
    String selectedType = isEdit ? (reminder['type'] as String) : 'Medication';
    final nameController = TextEditingController(text: isEdit ? (reminder['title'] as String) : '');
    
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    if (isEdit) {
      final timeParts = (reminder['time'] as String).split(':');
      selectedTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    }

    List<String> repeatDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDays = <String>{};
    if (isEdit) {
      final daysStr = reminder['days'] as String;
      if (daysStr == 'Daily') {
        selectedDays.addAll(repeatDays);
      } else {
        selectedDays.addAll(daysStr.split(','));
      }
    } else {
      selectedDays.addAll(repeatDays);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: PhiaColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PhiaColors.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit
                                ? AppLanguageHelper.translate(context, 'edit_reminder', defaultText: 'Edit Reminder')
                                : AppLanguageHelper.translate(context, 'new_reminder', defaultText: 'New Reminder'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.navyAnchor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Type Selection (Medication or Vitals)
                      Text(
                        'CATEGORY',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() => selectedType = 'Medication');
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedType == 'Medication'
                                        ? PhiaColors.primary
                                        : PhiaColors.borderSubtle,
                                    width: selectedType == 'Medication' ? 1.5 : 1,
                                  ),
                                  color: selectedType == 'Medication'
                                      ? const Color(0xFFE0F2FE)
                                      : PhiaColors.surfaceSubtle,
                                ),
                                child: Center(
                                  child: Text(
                                    'MEDICATION 💊',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: selectedType == 'Medication'
                                          ? PhiaColors.primary
                                          : PhiaColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() => selectedType = 'Vitals Check');
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedType == 'Vitals Check'
                                        ? PhiaColors.primary
                                        : PhiaColors.borderSubtle,
                                    width: selectedType == 'Vitals Check' ? 1.5 : 1,
                                  ),
                                  color: selectedType == 'Vitals Check'
                                      ? const Color(0xFFE0F2FE)
                                      : PhiaColors.surfaceSubtle,
                                ),
                                child: Center(
                                  child: Text(
                                    'VITALS CHECK 🩺',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: selectedType == 'Vitals Check'
                                          ? PhiaColors.primary
                                          : PhiaColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name input
                      Text(
                        selectedType == 'Medication'
                            ? 'MEDICATION NAME / DOSAGE'
                            : 'VITAL SIGN TO MEASURE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PhiaColors.borderSubtle),
                          color: PhiaColors.surfaceSubtle,
                        ),
                        child: TextField(
                          controller: nameController,
                          style: GoogleFonts.inter(color: PhiaColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: selectedType == 'Medication'
                                ? 'e.g., Metformin 500mg'
                                : 'e.g., Blood Pressure, Blood Glucose',
                            hintStyle: GoogleFonts.inter(color: PhiaColors.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time Selector
                      Text(
                        'SET TIME',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: PhiaColors.primary,
                                    surface: PhiaColors.surface,
                                    onSurface: PhiaColors.navyAnchor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            setModalState(() => selectedTime = time);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PhiaColors.borderSubtle),
                            color: PhiaColors.surfaceSubtle,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedTime.format(context),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const Icon(Icons.access_time_rounded, color: PhiaColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Repeat Days Selector
                      Text(
                        'REPEAT WEEKLY ON',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: repeatDays.map((day) {
                          final isSelected = selectedDays.contains(day);
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedDays.remove(day);
                                } else {
                                  selectedDays.add(day);
                                }
                              });
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? PhiaColors.primary
                                      : PhiaColors.borderSubtle,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                color: isSelected
                                    ? const Color(0xFFE0F2FE)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  day.substring(0, 1),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? PhiaColors.primary : PhiaColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PhiaColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a description / name')),
                            );
                            return;
                          }

                          final hourStr = selectedTime.hour.toString().padLeft(2, '0');
                          final minStr = selectedTime.minute.toString().padLeft(2, '0');
                          final timeStr = '$hourStr:$minStr';

                          final daysStr = repeatDays.where((d) => selectedDays.contains(d)).join(',');

                          final updatedReminder = {
                            'id': isEdit ? reminder['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
                            'title': name,
                            'type': selectedType,
                            'time': timeStr,
                            'days': daysStr.isEmpty ? 'Daily' : daysStr,
                            'is_active': isEdit ? reminder['is_active'] : 1,
                          };

                          await context.read<SettingsViewModel>().saveReminder(updatedReminder);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          isEdit ? 'Save Changes' : 'Create Reminder',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await context.read<SettingsViewModel>().deleteReminder(reminder['id']);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: PhiaColors.pulseRed, size: 18),
                          label: Text(
                            'Delete Reminder',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PhiaColors.pulseRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final reminders = settingsVM.remindersList;

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Vitals Reminders & Thresholds',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: reminders.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PhiaColors.surfaceSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_off_outlined,
                          size: 44,
                          color: PhiaColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Reminders Scheduled',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.navyAnchor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to schedule medication doses or vital signs monitoring checks.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: PhiaColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final rem = reminders[index];
                  final id = rem['id'] as String;
                  final title = rem['title'] as String;
                  final type = rem['type'] as String;
                  final time = rem['time'] as String;
                  final days = rem['days'] as String;
                  final isActive = (rem['is_active'] as int) == 1;

                  // Formatted time display
                  final parts = time.split(':');
                  final hour = int.parse(parts[0]);
                  final minute = int.parse(parts[1]);
                  final timeOfDay = TimeOfDay(hour: hour, minute: minute);
                  final formattedTime = timeOfDay.format(context);

                  return Dismissible(
                    key: Key(id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      decoration: BoxDecoration(
                        color: PhiaColors.pulseRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: PhiaColors.pulseRed),
                    ),
                    onDismissed: (direction) async {
                      await settingsVM.deleteReminder(id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"$title" reminder deleted.')),
                        );
                      }
                    },
                    child: GestureDetector(
                      onTap: () => _showReminderBottomSheet(context, reminder: rem),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PhiaColors.borderSubtle),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: type == 'Medication'
                                              ? const Color(0xFFE0F2FE)
                                              : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          type == 'Medication' ? 'MEDICATION 💊' : 'VITALS CHECK 🩺',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: type == 'Medication'
                                                ? PhiaColors.primary
                                                : const Color(0xFF16A34A),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: isActive ? PhiaColors.navyAnchor : PhiaColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? PhiaColors.textPrimary : PhiaColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    days,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: PhiaColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isActive,
                              activeThumbColor: Colors.white,
                              activeTrackColor: PhiaColors.primary,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: PhiaColors.borderSubtle,
                              onChanged: (val) {
                                settingsVM.toggleReminder(id, val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PhiaColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showReminderBottomSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Reminder',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
