import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/auth/presentation/login_screen.dart';
import 'package:phia_flutter/features/onboarding/welcome_screen.dart';
import 'package:provider/provider.dart';

/// Renders a screen on a small phone with large text: any overflow or layout
/// error fails the test.
Future<void> pumpSmall(WidgetTester tester, Widget screen, {double textScale = 1.3, bool dark = false}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(authRepository: AuthRepository(), healthRepository: HealthRepository()),
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  // Fonts are bundled at build time; tests must not download them.
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('welcome fits a small phone with large text ($mode)', (tester) async {
      await pumpSmall(tester, const WelcomeScreen(), dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('See a doctor, without the wait'), findsOneWidget);

      // Swipe through all slides.
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('login fits a small phone with large text ($mode)', (tester) async {
      await pumpSmall(tester, const LoginScreen(), dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Continue with DrGodly account'), findsOneWidget);
    });
  }
}
