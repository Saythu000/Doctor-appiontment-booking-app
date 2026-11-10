import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';

enum DayPeriod { morning, afternoon, evening }

extension on DayPeriod {
  String get label => switch (this) {
        DayPeriod.morning => 'Morning',
        DayPeriod.afternoon => 'Afternoon',
        DayPeriod.evening => 'Evening',
      };
  IconData get icon => switch (this) {
        DayPeriod.morning => Icons.wb_twilight_rounded,
        DayPeriod.afternoon => Icons.wb_sunny_rounded,
        DayPeriod.evening => Icons.nights_stay_rounded,
      };
}

DayPeriod periodOf(BookingSlot slot) {
  final hour = slot.startDateTime?.hour ?? 9;
  if (hour < 12) return DayPeriod.morning;
  if (hour < 17) return DayPeriod.afternoon;
  return DayPeriod.evening;
}

/// Morning / Afternoon / Evening chips above the free times of that part of
/// the day. Only real, free slots from the server are listed.
class SlotPicker extends StatefulWidget {
  final List<BookingSlot> slots;
  final int? selectedSlotId;
  final ValueChanged<BookingSlot> onSelected;

  const SlotPicker({super.key, required this.slots, required this.selectedSlotId, required this.onSelected});

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  DayPeriod? _period;

  Map<DayPeriod, List<BookingSlot>> get _groups {
    final groups = {for (final p in DayPeriod.values) p: <BookingSlot>[]};
    for (final s in widget.slots) {
      groups[periodOf(s)]!.add(s);
    }
    return groups;
  }

  @override
  void didUpdateWidget(SlotPicker old) {
    super.didUpdateWidget(old);
    if (!identical(old.slots, widget.slots)) _period = null;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final period = (_period != null && groups[_period]!.isNotEmpty)
        ? _period!
        : DayPeriod.values.firstWhere((p) => groups[p]!.isNotEmpty, orElse: () => DayPeriod.morning);
    final visible = groups[period]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in DayPeriod.values)
              ChoiceChip(
                avatar: Icon(p.icon, size: AppSizes.iconSm),
                label: Text('${p.label} (${groups[p]!.length})'),
                selected: p == period,
                onSelected: groups[p]!.isEmpty ? null : (_) => setState(() => _period = p),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (visible.isEmpty)
          Text('No free times in the ${period.label.toLowerCase()}.', style: context.text.bodyMedium)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in visible)
                _SlotChip(slot: s, selected: s.id == widget.selectedSlotId, onTap: () => widget.onSelected(s)),
            ],
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  final BookingSlot slot;
  final bool selected;
  final VoidCallback onTap;

  const _SlotChip({required this.slot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: slot.displayTime,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: AnimatedContainer(
          duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget, minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: selected ? colors.primary : colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: AppSizes.iconSm, color: colors.onPrimary),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                slot.displayTime,
                style: context.text.titleSmall!.copyWith(color: selected ? colors.onPrimary : colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
