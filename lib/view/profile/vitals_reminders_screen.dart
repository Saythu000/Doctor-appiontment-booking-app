import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
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
      backgroundColor: Colors.black,
      shape: const Border(
        top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                             isEdit
                                 ? AppLanguageHelper.translate(context, 'edit_reminder', defaultText: 'EDIT REMINDER')
                                 : AppLanguageHelper.translate(context, 'new_reminder', defaultText: 'NEW REMINDER'),
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Type Selection (Medication or Vitals)
                      Text(
                        'REMINDER CATEGORY',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.0,
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
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedType == 'Medication'
                                        ? PhiaColors.skyBlue
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                  color: selectedType == 'Medication'
                                      ? PhiaColors.skyBlue.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Center(
                                  child: Text(
                                    'MEDICATION 💊',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'Medication'
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() => selectedType = 'Vitals Check');
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedType == 'Vitals Check'
                                        ? PhiaColors.skyBlue
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                  color: selectedType == 'Vitals Check'
                                      ? PhiaColors.skyBlue.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Center(
                                  child: Text(
                                    'VITALS CHECK 🩺',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'Vitals Check'
                                          ? Colors.white
                                          : Colors.white60,
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
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          color: const Color(0xFF0D0E0F),
                        ),
                        child: TextField(
                          controller: nameController,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: selectedType == 'Medication'
                                ? 'e.g., Metformin 500mg'
                                : 'e.g., Blood Pressure, Blood Glucose',
                            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
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
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.0,
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
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: PhiaColors.skyBlue,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF0D0E0F),
                                    onSurface: Colors.white,
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            color: const Color(0xFF0D0E0F),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedTime.format(context),
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 20,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Icon(Icons.access_time, color: PhiaColors.skyBlue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Repeat Days Selector
                      Text(
                        'REPEAT WEEKLY ON',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.0,
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
                                      ? PhiaColors.skyBlue
                                      : Colors.white.withValues(alpha: 0.15),
                                ),
                                color: isSelected
                                    ? PhiaColors.skyBlue.withValues(alpha: 0.1)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  day.substring(0, 1),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                          isEdit ? 'UPDATE REMINDER' : 'SAVE REMINDER',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () async {
                            await context.read<SettingsViewModel>().deleteReminder(reminder['id']);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline, color: PhiaColors.pulseRed),
                          label: Text(
                            'DELETE REMINDER',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 16,
                              letterSpacing: 1.0,
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                       Text(
                         AppLanguageHelper.translate(context, 'meds_vitals_reminders', defaultText: 'MEDS & VITALS REMINDERS'),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 22,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: reminders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'NO REMINDERS SCHEDULED',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 20,
                                  color: Colors.white38,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to schedule medication doses\nor vital signs monitoring checks.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                child: const Icon(Icons.delete, color: Colors.redAccent),
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
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: PhiaColors.surface,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
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
                                                Text(
                                                  type == 'Medication' ? '💊' : '🩺',
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  type.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: PhiaColors.skyBlue,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              formattedTime,
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 32,
                                                color: isActive ? Colors.white : Colors.white38,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              title,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isActive ? Colors.white : Colors.white38,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              days,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: Colors.white.withValues(alpha: 0.38),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: isActive,
                                        activeColor: PhiaColors.skyBlue,
                                        inactiveThumbColor: Colors.white30,
                                        inactiveTrackColor: Colors.white10,
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
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        onPressed: () => _showReminderBottomSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
