import 'package:flutter_test/flutter_test.dart';

/// Checks the screen on display against Flutter's Android accessibility
/// guidelines: tap targets of at least 48 x 48dp, a label on every tappable
/// item, and readable text contrast.
Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  // Let entrance fades finish, so text is checked at its final colour.
  // (pumpAndSettle would never end: some screens have looping animations.)
  await _wait(tester);
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  // Contrast is measured at 3x pixel density, like a real phone, with the
  // same screen size in dp. At 1x, small text is mostly anti-aliased edge
  // pixels, so its colour cannot be read reliably.
  final view = tester.view;
  final oldRatio = view.devicePixelRatio;
  final logical = view.physicalSize / oldRatio;
  view
    ..devicePixelRatio = 3
    ..physicalSize = logical * 3;
  await _wait(tester);
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  view
    ..devicePixelRatio = oldRatio
    ..physicalSize = logical * oldRatio;
  await tester.pump();
  handle.dispose();
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
