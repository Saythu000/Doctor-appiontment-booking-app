import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/data/service/intake_service.dart';
import 'package:phia_flutter/data/service/voice_intake_service.dart';
import 'package:phia_flutter/domain/model/intake_models.dart';
import 'package:phia_flutter/viewmodel/voice_intake_viewmodel.dart';

/// Fake WebSocket/audio service: no platform channels, events pushed by tests.
class FakeVoiceService implements VoiceIntakeService {
  final _controller = StreamController<VoiceAgentEvent>.broadcast();
  int disconnectCalls = 0;

  void emit(VoiceAgentEvent e) => _controller.add(e);
  void failSocket() => _controller.addError(Exception('socket closed'));

  @override
  Stream<VoiceAgentEvent> get events => _controller.stream;

  @override
  Future<void> connect({
    required String authToken,
    String? patientContext,
    String? wsUrlOverride,
  }) async {}

  @override
  Future<void> disconnect() async => disconnectCalls++;

  @override
  void setMuted(bool muted) {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake intake backend that records which patient an intake was saved for.
class FakeIntakeService extends IntakeService {
  final List<int?> createdForPatients = [];
  IntakeRecord? recordToReturn = IntakeRecord(id: 7, status: 'IN_PROGRESS');
  bool updateResult = true;

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
  late FakeVoiceService voice;
  late FakeIntakeService intake;
  late VoiceIntakeViewModel vm;

  setUp(() {
    voice = FakeVoiceService();
    intake = FakeIntakeService();
    vm = VoiceIntakeViewModel(voiceService: voice, intakeService: intake);
  });

  Future<void> sayHello() async {
    voice.emit(VoiceAgentEvent(type: 'assistant_text', text: 'Hello, how can I help?'));
    await Future<void>.delayed(Duration.zero);
  }

  test('agent-ended call saves the intake to the patient captured at start', () async {
    await vm.startCall(authToken: 't', patientFhirId: 42, orgId: 'org-1');
    await sayHello();

    voice.emit(VoiceAgentEvent(type: 'status_end'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(intake.createdForPatients, [42]);
    expect(vm.callState, VoiceCallState.completed);
    expect(vm.savedIntakeRecordId, 7);
  });

  test('without a patient id the intake is saved with patient_fhir_id omitted, never a fallback patient', () async {
    await vm.startCall(authToken: 't');
    await sayHello();

    await vm.endCall(authToken: 't');

    expect(intake.createdForPatients, [null]);
    expect(vm.callState, VoiceCallState.completed);
  });

  test('a failed server create is reported as an error, not as completed', () async {
    intake.recordToReturn = null;
    await vm.startCall(authToken: 't', patientFhirId: 42);
    await sayHello();

    await vm.endCall(authToken: 't');

    expect(vm.callState, VoiceCallState.error);
  });

  test('a failed conversation update is reported as an error', () async {
    intake.updateResult = false;
    await vm.startCall(authToken: 't', patientFhirId: 42);
    await sayHello();

    await vm.endCall(authToken: 't');

    expect(vm.callState, VoiceCallState.error);
  });

  test('abortCall stops the connection without saving anything', () async {
    await vm.startCall(authToken: 't', patientFhirId: 42);
    await sayHello();
    final before = voice.disconnectCalls;

    await vm.abortCall();

    expect(voice.disconnectCalls, greaterThan(before));
    expect(vm.callState, VoiceCallState.offline);
    expect(vm.isCallActive, isFalse);
    expect(intake.createdForPatients, isEmpty);
  });

  test('a failed save can be retried without losing the conversation or duplicating the record', () async {
    intake.updateResult = false;
    await vm.startCall(authToken: 't', patientFhirId: 42);
    await sayHello();
    await vm.endCall(authToken: 't');
    expect(vm.callState, VoiceCallState.error);
    expect(vm.canRetrySave, isTrue);
    expect(vm.committedMessages, isNotEmpty);

    intake.updateResult = true;
    await vm.retrySave(authToken: 't');

    expect(vm.callState, VoiceCallState.completed);
    expect(intake.createdForPatients, [42], reason: 'the record created on the first try is reused');
  });

  test('a dropped connection stops the call, keeps the transcript and allows saving', () async {
    await vm.startCall(authToken: 't', patientFhirId: 42);
    await sayHello();

    voice.failSocket();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(vm.isCallActive, isFalse);
    expect(vm.callState, VoiceCallState.error);
    expect(vm.canRetrySave, isTrue);

    await vm.retrySave(authToken: 't');
    expect(vm.callState, VoiceCallState.completed);
  });
}
