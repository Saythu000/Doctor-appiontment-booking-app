import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/data/local/health_repository.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('signed-out start: the brand intro plays in full (4.5 s) before Welcome', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(path: AppRoutes.welcome, builder: (_, __) => const Text('WELCOME')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(authRepository: AuthRepository(), healthRepository: HealthRepository()),
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );

    // The sign-in check finishes almost at once (nothing stored)...
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    // ...but at 4 s the intro is still showing.
    expect(find.text('WELCOME'), findsNothing);
    expect(find.text('DrGodly'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
    expect(find.text('WELCOME'), findsOneWidget);
  });
}
