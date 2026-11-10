import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

enum FeedbackType { info, success, error }

/// Shows one short message at the bottom of the screen, replacing any message
/// already showing (so messages never pile up).
void showAppMessage(
  BuildContext context,
  String message, {
  FeedbackType type = FeedbackType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final colors = context.colors;
  final icon = switch (type) {
    FeedbackType.success => Icons.check_circle_rounded,
    FeedbackType.error => Icons.error_rounded,
    FeedbackType.info => Icons.info_rounded,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: type == FeedbackType.error ? colors.danger.foreground : null,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: Colors.white, onPressed: onAction ?? () {}),
      ),
    );
}

/// Standard yes/no confirmation. Returns true only if the user confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: colors.danger.foreground) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
