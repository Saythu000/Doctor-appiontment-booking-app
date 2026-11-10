import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Horizontal strip of days. Days the doctor does not work are shown but
/// cannot be picked.
class DateStrip extends StatefulWidget {
  final List<DateTime> days;
  final DateTime selected;
  final bool Function(DateTime day) isAvailable;
  final ValueChanged<DateTime> onSelected;

  const DateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.isAvailable,
    required this.onSelected,
  });

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  static const double _itemWidth = 64;
  static const double _gap = AppSpacing.sm;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final index = widget.days.indexWhere((d) => DateUtils.isSameDay(d, widget.selected));
    // Start with the selected day in view (it may be days ahead of today).
    _scroll = ScrollController(initialScrollOffset: index <= 1 ? 0 : (index - 1) * (_itemWidth + _gap));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Height grows with the text size so large text never clips.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: 76 + 30 * (scale - 1),
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = widget.days[i];
          return _DayTile(
            day: d,
            width: _itemWidth,
            selected: DateUtils.isSameDay(d, widget.selected),
            available: widget.isAvailable(d),
            onTap: () => widget.onSelected(d),
          );
        },
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime day;
  final double width;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  const _DayTile({
    required this.day,
    required this.width,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected
        ? colors.onPrimary
        : available
            ? colors.textPrimary
            : colors.textMuted;
    final bg = selected
        ? colors.primary
        : available
            ? colors.surface
            : colors.surfaceMuted;
    final label = DateFormat('EEEE, MMMM d').format(day);

    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: available ? label : '$label, not available',
      excludeSemantics: true,
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: AppRadius.mdAll,
        child: AnimatedContainer(
          duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
          width: width,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: selected ? colors.primary : colors.border),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('EEE').format(day), style: context.text.labelMedium!.copyWith(color: fg)),
                  Text(
                    '${day.day}',
                    style: context.text.titleLarge!.copyWith(
                      color: fg,
                      decoration: available ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  Text(DateFormat('MMM').format(day), style: context.text.labelMedium!.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
