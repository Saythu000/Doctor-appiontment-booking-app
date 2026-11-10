import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Text field and round send button at the bottom of the intake chat.
/// The send button is disabled while the assistant replies or the field is empty.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !busy,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: busy ? 'Assistant is replying…' : 'Type your answer',
                  fillColor: colors.background,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = !busy && value.text.trim().isNotEmpty;
                return IconButton.filled(
                  onPressed: canSend ? onSend : null,
                  tooltip: 'Send',
                  iconSize: AppSizes.iconLg,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceMuted,
                    disabledForegroundColor: colors.textMuted,
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
