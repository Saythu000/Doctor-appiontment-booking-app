import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/features/intake/data/intake_service.dart';
import 'package:phia_flutter/features/intake/domain/intake_models.dart';
import 'package:phia_flutter/features/intake/presentation/intake_viewmodel.dart';

/// Fake chat-intake backend: one canned agent reply, configurable save result.
class FakeChatIntakeService extends IntakeService {
  int createCalls = 0;
  final List<int?> createdForPatients = [];
  IntakeRecord? recordToReturn = IntakeRecord(id: 11, status: 'IN_PROGRESS');
  bool updateResult = true;

  @override
  Stream<IntakeStreamChunk> streamChatTurn({
    required String message,
    required String? sessionId,
    required String authToken,
  }) async* {
    yield IntakeStreamChunk(type: 'text_delta', textDelta: 'How long have you had it?', sessionId: 's1');
    yield IntakeStreamChunk(type: 'agent_end', sessionId: 's1');
  }

  @override
  Future<Map<String, dynamic>?> generateClinicalReport({
    required List<IntakeChatMessage> conversation,
    required String authToken,
  }) async =>
      null;

  @override
  Future<IntakeRecord?> createIntakeRecord({
    int? patientFhirId,
    String mode = 'TEXT',
    required String authToken,
    String? orgId,
  }) async {
    createCalls++;
    createdForPatients.add(patientFhirId);
    return recordToReturn;
  }

  @override
  Future<bool> updateIntakeRecord({
    required int id,
    required List<IntakeChatMessage> conversation,
    Map<String, dynamic>? report,
    required String authToken,
    String? orgId,
  }) async =>
      updateResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatIntakeService service;
  late IntakeViewModel vm;

  Future<void> chatOnce() async {
    await vm.sendMessage(text: 'I have a headache', authToken: 'jwt', patientFhirId: 42);
    // Let the fake stream finish.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    service = FakeChatIntakeService();
    vm = IntakeViewModel(intakeService: service);
  });

  test('a successful save completes the intake', () async {
    await chatOnce();
    await vm.finishIntake(authToken: 'jwt', patientFhirId: 42, orgId: 'org');
    expect(vm.state, IntakeState.completed);
    expect(vm.errorMessage, isNull);
  });

  test('server create failure is an error, not a fake "completed"', () async {
    service.recordToReturn = null;
    await chatOnce();
    await vm.finishIntake(authToken: 'jwt', patientFhirId: 42, orgId: 'org');
    expect(vm.state, IntakeState.error);
    expect(vm.errorMessage, isNotNull);
    expect(vm.messages, isNotEmpty, reason: 'conversation is kept for retry');
  });

  test('update failure is an error, and retry reuses the created record', () async {
    service.updateResult = false;
    await chatOnce();
    await vm.finishIntake(authToken: 'jwt', patientFhirId: 42, orgId: 'org');
    expect(vm.state, IntakeState.error);
    expect(service.createCalls, 1);

    service.updateResult = true;
    await vm.finishIntake(authToken: 'jwt', patientFhirId: 42, orgId: 'org');
    expect(vm.state, IntakeState.completed);
    expect(service.createCalls, 1, reason: 'must not create a duplicate intake record');
  });

  test('no patient id: saved with patient_fhir_id omitted (text guide §5.1)', () async {
    await chatOnce();
    await vm.finishIntake(authToken: 'jwt', orgId: 'org');
    expect(vm.state, IntakeState.completed);
    expect(service.createdForPatients, [null]);
  });
}
