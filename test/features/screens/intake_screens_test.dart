import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/intake/data/voice_intake_service.dart';
import 'package:phia_flutter/features/intake/domain/intake_models.dart';
import 'package:phia_flutter/features/intake/presentation/intake_chat_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_completion_screen.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_screen.dart';
import 'package:phia_flutter/features/intake/presentation/voice_intake_viewmodel.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:provider/provider.dart';

import '../intake/intake_viewmodel_save_test.dart' show FakeChatIntakeService;
import '../intake/voice_intake_viewmodel_test.dart' show FakeVoiceService, FakeIntakeService;

/// A JWT that `AuthViewModel.isJwtValid` accepts (expires in an hour).
String _validJwt() {
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp}))).replaceAll('=', '');
  return 'e30.$payload.sig';
}

class FakeAuthVM extends ChangeNotifier implements AuthViewModel {
  final String token = _validJwt();

  @override
  User? get user => User(id: 'u1', email: 'alex@example.com', name: 'Alex Rivera');
  @override
  String? get jwtToken => token;
  @override
  String? get idToken => null;
  @override
  String? get orgId => 'org1';
  @override
  Future<String?> refreshToken() async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProfileVM extends ChangeNotifier implements ProfileViewModel {
  @override
  PlainPatient? currentProfile = PlainPatient(id: 42, active: true, birthDate: '1990-01-01');
  @override
  int? get patientFhirId => currentProfile?.id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Renders [screen] on a 320x640 phone with large text inside a tiny router,
/// so `GoRouterState.of(context)` works. Any overflow fails the test.
Future<void> pumpSmall(
  WidgetTester tester,
  Widget screen, {
  required double textScale,
  required bool dark,
  IntakeViewModel? chat,
  VoiceIntakeViewModel? voice,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => screen)]);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: FakeAuthVM()),
        ChangeNotifierProvider<ProfileViewModel>.value(value: FakeProfileVM()),
        ChangeNotifierProvider<IntakeViewModel>.value(
            value: chat ?? IntakeViewModel(intakeService: FakeChatIntakeService())),
        ChangeNotifierProvider<VoiceIntakeViewModel>.value(
            value: voice ??
                VoiceIntakeViewModel(voiceService: FakeVoiceService(), intakeService: FakeIntakeService())),
      ],
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('risk words', () {
    test('every level maps to a tone and words, unknown stays neutral', () {
      expect(intakeRiskStyle('low').tone, StatusTone.success);
      expect(intakeRiskStyle('Moderate').tone, StatusTone.warning);
      expect(intakeRiskStyle('medium').tone, StatusTone.warning);
      expect(intakeRiskStyle('HIGH').tone, StatusTone.danger);
      expect(intakeRiskStyle('critical').label, 'Urgent');
      expect(intakeRiskStyle('weird').tone, StatusTone.neutral);
      expect(intakeRiskStyle('weird').label, 'Priority: weird');
    });
  });

  for (final dark in [false, true]) {
    for (final scale in [1.3, 2.0]) {
      final label = '${dark ? 'dark' : 'light'}, ${(scale * 100).round()}% text';

      testWidgets('chat intro and conversation fit ($label)', (tester) async {
        await pumpSmall(tester, const IntakeChatScreen(), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('How are you feeling?'), findsOneWidget);
        expect(find.byTooltip('Send'), findsOneWidget);

        // Start from an example answer: the patient bubble and the reply appear.
        await tester.ensureVisible(find.text("I've had a headache for 3 days"));
        await tester.tap(find.text("I've had a headache for 3 days"));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('How long have you had it?'), findsOneWidget);
        expect(find.text('Finish'), findsOneWidget);
      });

      testWidgets('voice call screen fits ($label)', (tester) async {
        final service = FakeVoiceService();
        final voice = VoiceIntakeViewModel(voiceService: service, intakeService: FakeIntakeService());
        await pumpSmall(tester, const VoiceIntakeScreen(), textScale: scale, dark: dark, voice: voice);
        expect(tester.takeException(), isNull);

        service.emit(VoiceAgentEvent(type: 'assistant_text', text: 'Hello, how can I help you today?'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        // At 200% the orb scrolls with the transcript; scroll to the greeting.
        await tester.scrollUntilVisible(
          find.text('Hello, how can I help you today?'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        if (voice.isCallActive) {
          expect(find.byTooltip('End call and save'), findsOneWidget);
          expect(find.byTooltip('Turn microphone off'), findsOneWidget);
        } else {
          expect(find.text('Start call'), findsOneWidget);
        }

        // Leaving the screen stops the call (dispose aborts it).
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('completion with a high-risk report fits ($label)', (tester) async {
        final args = IntakeCompletionArgs(
          mode: IntakeMode.voice,
          intakeId: 128,
          turnCount: 9,
          doctorArgs: const {'name': 'Dr. Priya Raman Venkataraman'},
          clinicalReport: IntakeClinicalReport(
            clinicalOverview: 'Three days of headache with light sensitivity and mild fever.',
            riskLevel: 'high',
            redFlags: const ['Stiff neck', 'Fever above 39 °C'],
            rawJson: const {},
          ),
        );
        await pumpSmall(tester, IntakeCompletionScreen(args: args), textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('High priority'), findsOneWidget);
        expect(find.textContaining('Reference number: 128'), findsOneWidget);
        expect(find.textContaining('Intake #'), findsNothing);
        expect(find.text('Continue booking with Dr. Priya Raman Venkataraman'), findsOneWidget);
        expect(find.text('Go to Home'), findsOneWidget);
      });

      testWidgets('completion without report or id stays honest ($label)', (tester) async {
        await pumpSmall(
          tester,
          const IntakeCompletionScreen(args: IntakeCompletionArgs(mode: IntakeMode.chat)),
          textScale: scale,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Reference number'), findsNothing);
        expect(find.text('Book a doctor'), findsOneWidget);
      });
    }
  }
}
