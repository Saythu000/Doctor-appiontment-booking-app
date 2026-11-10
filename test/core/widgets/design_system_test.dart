import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: Center(child: child)),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('a loading button cannot be tapped again', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton(label: 'Book', isLoading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an idle button runs its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton(label: 'Book', onPressed: () => taps++)));
    await tester.tap(find.text('Book'));
    expect(taps, 1);
  });

  testWidgets('error view offers a retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(ErrorView(message: 'Offline', onRetry: () => retried = true)));
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  test('text and status colours meet WCAG AA (4.5:1) in light and dark', () {
    for (final c in [AppColors.light, AppColors.dark]) {
      expect(_contrast(c.textPrimary, c.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.textSecondary, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.textMuted, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      for (final t in StatusTone.values) {
        final tone = c.tone(t);
        expect(_contrast(tone.foreground, tone.background), greaterThanOrEqualTo(4.5), reason: '$t');
      }
    }
  });
}
