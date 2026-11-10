import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Corner radius of the bubble's "tail" corner.
const double _tail = 4;

/// Small round avatar marking messages from the DrGodly assistant.
class AssistantAvatar extends StatelessWidget {
  final double size;
  const AssistantAvatar({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
        child: Icon(Icons.health_and_safety_rounded, size: size * 0.6, color: colors.onPrimaryContainer),
      ),
    );
  }
}

/// One message in an intake conversation (chat or voice transcript).
///
/// Patient messages sit on the right in the primary colour; assistant
/// messages sit on the left with an avatar. [pending] marks text that is
/// still being recognised or spoken (shown slightly faded, in italics for the
/// patient's live speech).
class ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final bool pending;
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.isUser,
    required this.text,
    this.pending = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final background = isUser ? colors.primary : colors.surface;
    final foreground = isUser ? colors.onPrimary : colors.textPrimary;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Opacity(
        opacity: pending ? 0.75 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2, vertical: AppSpacing.md - 2),
          decoration: BoxDecoration(
            color: background,
            border: isUser ? null : Border.all(color: colors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isUser ? AppRadius.lg : _tail),
              bottomRight: Radius.circular(isUser ? _tail : AppRadius.lg),
            ),
          ),
          child: Text(
            text,
            style: context.text.bodyMedium!.copyWith(
              color: foreground,
              fontStyle: pending && isUser ? FontStyle.italic : null,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: isUser ? 'You said' : 'Assistant said',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              if (showAvatar) const AssistantAvatar() else const SizedBox(width: 28),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

/// "Assistant is typing" bubble with three dots rising in turn.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'Assistant is typing',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const AssistantAvatar(),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(_tail),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) _dot(colors.textMuted, i),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, int i) {
    // Each dot rises during its own third of the cycle.
    final t = ((_controller.value - i * 0.18) % 1.0);
    final lift = t < 0.35 ? Curves.easeInOut.transform((t < 0.175 ? t : 0.35 - t) / 0.175) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Transform.translate(
        offset: Offset(0, -4 * lift),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.5 + 0.5 * lift), shape: BoxShape.circle),
        ),
      ),
    );
  }
}
