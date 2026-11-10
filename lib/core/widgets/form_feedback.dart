import 'package:flutter/material.dart';

/// Validates [form]. When something is wrong, scrolls the highest wrong
/// field into view, so the user sees what to fix even when it is above the
/// button they pressed. (Flutter's Form already reads the first error aloud
/// for screen-reader users.) Returns true when the form is valid.
bool validateForm(BuildContext context, GlobalKey<FormState> form) {
  final state = form.currentState;
  if (state == null) return false;
  final invalid = state.validateGranularly();
  if (invalid.isEmpty) return true;

  // validateGranularly returns fields in no fixed order: pick the one
  // highest on the screen.
  FormFieldState<Object?>? first;
  double? firstTop;
  for (final field in invalid) {
    final box = field.context.findRenderObject();
    if (box is! RenderBox || !box.attached) continue;
    final top = box.localToGlobal(Offset.zero).dy;
    if (firstTop == null || top < firstTop) {
      first = field;
      firstTop = top;
    }
  }
  Scrollable.ensureVisible(
    (first ?? invalid.first).context,
    alignment: 0.2,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
  return false;
}
