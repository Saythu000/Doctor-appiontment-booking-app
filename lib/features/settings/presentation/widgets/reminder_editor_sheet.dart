import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/form_feedback.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:provider/provider.dart';

/// Day order used in the stored `days` string ("Sun,Mon,..."), shared with
/// NotificationService. An empty selection is stored as "Daily".
const reminderDayOrder = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const reminderTypeMedication = 'Medication';
const reminderTypeVitals = 'Vitals Check';

IconData reminderTypeIcon(String type) =>
    type == reminderTypeVitals ? Icons.monitor_heart_outlined : Icons.medication_outlined;

/// Plain description of a stored `days` value, e.g. "Every day" or "Mon, Wed, Fri".
String describeReminderDays(String days) {
  if (days.trim().isEmpty || days.toLowerCase() == 'daily') return 'Every day';
  final list = days.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  if (list.length == 7) return 'Every day';
  const weekdays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  if (list.length == 5 && list.toSet().containsAll(weekdays)) return 'Weekdays';
  if (list.length == 2 && list.toSet().containsAll({'Sat', 'Sun'})) return 'Weekends';
  return list.join(', ');
}

/// Opens the add/edit reminder sheet. Returns when it closes.
Future<void> showReminderEditor(BuildContext context, {Map<String, dynamic>? reminder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReminderEditorSheet(reminder: reminder),
  );
}

Future<bool> confirmDeleteReminder(BuildContext context, String title) {
  return confirmAction(
    context,
    title: 'Delete reminder?',
    message: title.isEmpty ? 'This reminder will stop.' : '"$title" will stop reminding you.',
    confirmLabel: 'Delete',
    destructive: true,
  );
}

class ReminderEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? reminder;
  const ReminderEditorSheet({super.key, this.reminder});

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _type;
  late TimeOfDay _time;
  final Set<String> _days = {};
  bool _daily = true;
  bool _saving = false;

  bool get _isEdit => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _name = TextEditingController(text: (r?['title'] as String?) ?? '');
    _type = (r?['type'] as String?) == reminderTypeVitals ? reminderTypeVitals : reminderTypeMedication;
    _time = const TimeOfDay(hour: 8, minute: 0);
    final parts = ((r?['time'] as String?) ?? '').split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) _time = TimeOfDay(hour: h, minute: m);
    }
    final days = (r?['days'] as String?) ?? 'Daily';
    if (days.toLowerCase() != 'daily') {
      _days.addAll(days.split(',').map((d) => d.trim()).where(reminderDayOrder.contains));
      _daily = _days.isEmpty || _days.length == 7;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_saving || !validateForm(context, _formKey)) return;
    final timeStr = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final daysStr = _daily ? '' : reminderDayOrder.where(_days.contains).join(',');
    final updated = <String, dynamic>{
      'id': _isEdit ? widget.reminder!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _name.text.trim(),
      'type': _type,
      'time': timeStr,
      'days': daysStr.isEmpty ? 'Daily' : daysStr,
      'is_active': _isEdit ? widget.reminder!['is_active'] : 1,
    };

    setState(() => _saving = true);
    try {
      await context.read<SettingsViewModel>().saveReminder(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(context, "Couldn't save the reminder. Please try again.", type: FeedbackType.error);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final title = _name.text.trim();
    if (!await confirmDeleteReminder(context, title)) return;
    if (!mounted) return;
    final vm = context.read<SettingsViewModel>();
    final navigator = Navigator.of(context);
    navigator.pop();
    await vm.deleteReminder(widget.reminder!['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMed = _type == reminderTypeMedication;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(_isEdit ? 'Edit reminder' : 'New reminder', style: context.text.titleLarge),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Type', style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (value, label) in const [
                    (reminderTypeMedication, 'Medicine'),
                    (reminderTypeVitals, 'Check vitals'),
                  ])
                    ChoiceChip(
                      avatar: Icon(reminderTypeIcon(value), size: AppSizes.iconSm),
                      label: Text(label),
                      selected: _type == value,
                      onSelected: (_) => setState(() => _type = value),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isMed ? 'Medicine and dose' : 'What to measure',
                  hintText: isMed ? 'e.g. Metformin 500 mg' : 'e.g. Blood pressure',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Time', style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                  onTap: _pickTime,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: colors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(_time.format(context), style: context.text.titleMedium)),
                          Text('Change', style: context.text.labelLarge!.copyWith(color: colors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Repeat', style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Every day'),
                    selected: _daily,
                    onSelected: (_) => setState(() => _daily = true),
                  ),
                  ChoiceChip(
                    label: const Text('Pick days'),
                    selected: !_daily,
                    onSelected: (_) => setState(() => _daily = false),
                  ),
                ],
              ),
              if (!_daily) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final day in reminderDayOrder)
                      FilterChip(
                        label: Text(day),
                        selected: _days.contains(day),
                        onSelected: (on) => setState(() => on ? _days.add(day) : _days.remove(day)),
                      ),
                  ],
                ),
                if (_days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text('No days picked: it will remind you every day.', style: context.text.bodySmall),
                  ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Add reminder',
                isLoading: _saving,
                onPressed: _save,
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton.text(
                  label: 'Delete reminder',
                  icon: Icons.delete_outline_rounded,
                  expand: true,
                  onPressed: _saving ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
