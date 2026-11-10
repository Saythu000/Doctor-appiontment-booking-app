import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';

/// Controls at the bottom of the voice intake screen.
///
/// In a call: Mute, a large red End call button, Restart.
/// After a failed save: "Save conversation" and "Discard and start a new call".
/// Otherwise: "Start call".
class VoiceCallDock extends StatelessWidget {
  final bool inCall;
  final bool busy;
  final bool muted;
  final bool canRetrySave;
  final VoidCallback onToggleMute;
  final VoidCallback onEnd;
  final VoidCallback onRestart;
  final VoidCallback onStart;
  final VoidCallback onRetrySave;
  final VoidCallback onDiscard;

  const VoiceCallDock({
    super.key,
    required this.inCall,
    required this.busy,
    required this.muted,
    required this.canRetrySave,
    required this.onToggleMute,
    required this.onEnd,
    required this.onRestart,
    required this.onStart,
    required this.onRetrySave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget content;
    if (inCall) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundControl(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: muted ? 'Unmute' : 'Mute',
            tooltip: muted ? 'Turn microphone on' : 'Turn microphone off',
            selected: muted,
            onPressed: busy ? null : onToggleMute,
          ),
          _RoundControl(
            icon: Icons.call_end_rounded,
            label: 'End call',
            tooltip: 'End call and save',
            size: 72,
            danger: true,
            onPressed: busy ? null : onEnd,
          ),
          _RoundControl(
            icon: Icons.restart_alt_rounded,
            label: 'Restart',
            tooltip: 'Start the call again',
            onPressed: busy ? null : onRestart,
          ),
        ],
      );
    } else if (canRetrySave) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Save conversation',
            icon: Icons.cloud_upload_outlined,
            isLoading: busy,
            onPressed: onRetrySave,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.text(
            label: 'Discard and start a new call',
            onPressed: busy ? null : onDiscard,
          ),
        ],
      );
    } else {
      content = AppButton(
        label: 'Start call',
        icon: Icons.call_rounded,
        isLoading: busy,
        onPressed: onStart,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: content,
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool danger;
  final bool selected;

  const _RoundControl({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.size = AppSizes.minTouchTarget + 8,
    this.danger = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dangerTone = colors.tone(StatusTone.danger);
    final Color bg;
    final Color fg;
    if (danger) {
      // Solid red: the one action that ends the call.
      bg = dangerTone.foreground;
      fg = colors.surface;
    } else if (selected) {
      bg = dangerTone.background;
      fg = dangerTone.foreground;
    } else {
      bg = colors.surfaceMuted;
      fg = colors.textPrimary;
    }

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: onPressed != null,
            label: label,
            child: Tooltip(
            message: tooltip,
            child: Material(
              color: onPressed == null ? colors.surfaceMuted : bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, size: size * 0.45, color: onPressed == null ? colors.textMuted : fg),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Text(label, style: context.text.labelMedium, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
