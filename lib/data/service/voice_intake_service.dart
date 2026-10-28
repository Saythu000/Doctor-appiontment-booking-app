import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/api_constants.dart';

/// Event emitted from the Voice Intake Agent WebSocket
class VoiceAgentEvent {
  final String type; // 'status' | 'status_end' | 'transcript' | 'text' | 'text_delta' | 'assistant_text' | 'audio' | 'error'
  final String? status;
  final String? text;
  final String? audioBase64;
  final String? message;

  VoiceAgentEvent({
    required this.type,
    this.status,
    this.text,
    this.audioBase64,
    this.message,
  });

  factory VoiceAgentEvent.fromJson(Map<String, dynamic> json) {
    return VoiceAgentEvent(
      type: json['type']?.toString() ?? 'unknown',
      status: json['status']?.toString(),
      text: json['text']?.toString(),
      audioBase64: json['audio']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class VoiceIntakeService {
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micStreamSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isMuted = false;
  bool _isConnected = false;

  final _eventController = StreamController<VoiceAgentEvent>.broadcast();
  Stream<VoiceAgentEvent> get events => _eventController.stream;

  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;

  // Audio buffering engine for gapless playback
  final BytesBuilder _turnPcmBuilder = BytesBuilder();
  Timer? _turnPlaybackTimer;
  bool _isPlaying = false;
  int _totalBytesSent = 0;
  int _micChunksSent = 0;

  bool get isPlaying => _isPlaying;

  void setMuted(bool muted) {
    _isMuted = muted;
  }

  /// Open WebSocket connection (§2.1)
  /// `{INTAKE_VOICE_AGENT_WS_URL}/ws/audio?patient_context=<url-encoded>&token=<jwt>`
  Future<void> connect({
    required String authToken,
    String? patientContext,
    String? wsUrlOverride,
  }) async {
    await disconnect();

    String baseWsUrl = (wsUrlOverride != null && wsUrlOverride.isNotEmpty)
        ? wsUrlOverride.trim()
        : ApiConstants.defaultIntakeVoiceAgentWsUrl;

    // Convert http(s) to ws(s) if needed
    if (baseWsUrl.startsWith('https://')) {
      baseWsUrl = 'wss://${baseWsUrl.substring(8)}';
    } else if (baseWsUrl.startsWith('http://')) {
      baseWsUrl = 'ws://${baseWsUrl.substring(7)}';
    }

    if (!baseWsUrl.endsWith('/ws/audio')) {
      if (baseWsUrl.endsWith('/')) {
        baseWsUrl = '${baseWsUrl}ws/audio';
      } else {
        baseWsUrl = '$baseWsUrl/ws/audio';
      }
    }

    // Build URI with url-encoded query parameters
    final Map<String, String> queryParams = {
      'token': authToken,
      if (patientContext != null && patientContext.trim().isNotEmpty)
        'patient_context': patientContext.trim(),
    };

    final uri = Uri.parse(baseWsUrl).replace(queryParameters: queryParams);
    debugPrint('[VoiceIntakeService] Connecting to WebSocket: $uri');

    // Configure global AudioContext for voice communication so AudioPlayer never steals focus from recorder
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[VoiceIntakeService] Error configuring AudioContext: $e');
    }

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;
      _isConnected = true;
      debugPrint('[VoiceIntakeService] WebSocket connected successfully');

      // Handle incoming text JSON frames (§4)
      _socketSubscription = _channel?.stream.listen(
        (data) {
          try {
            if (data is String) {
              final Map<String, dynamic> json = jsonDecode(data);
              final event = VoiceAgentEvent.fromJson(json);

              debugPrint('[VoiceIntakeService] Received event type=${event.type} status=${event.status} text=${event.text}');

              // Handle audio stream buffering (§3.2)
              if (event.type == 'audio' && event.audioBase64 != null) {
                _onAudioChunkReceived(event.audioBase64!);
              } else if (event.type == 'status' && (event.status == 'ready' || event.status == 'ready_for_input')) {
                // Assistant finished sending speech chunks for this turn -> flush and play single cohesive WAV
                _flushAndPlayTurnAudio();
              } else if (event.type == 'transcript' && (event.text?.trim().isNotEmpty ?? false)) {
                // Barge-in: user spoke, stop any active agent speech
                stopAudioPlayback();
              }

              _eventController.add(event);
            }
          } catch (e) {
            debugPrint('[VoiceIntakeService] Error parsing incoming frame: $e');
          }
        },
        onError: (err) {
          debugPrint('[VoiceIntakeService] WebSocket error: $err');
          _isConnected = false;
          _eventController.add(VoiceAgentEvent(type: 'error', message: err.toString()));
        },
        onDone: () {
          debugPrint('[VoiceIntakeService] WebSocket closed');
          _isConnected = false;
          _eventController.add(VoiceAgentEvent(type: 'status_end'));
        },
      );

      // Start microphone streaming once the socket is open (§2.2, §3.1)
      await _startMicrophone();
    } catch (e) {
      _isConnected = false;
      debugPrint('[VoiceIntakeService] Connect error: $e');
      rethrow;
    }
  }

  /// Microphone stream: 16-bit PCM, 16000 Hz, mono, little-endian (§3.1)
  Future<void> _startMicrophone() async {
    try {
      // Ensure microphone runtime permission is granted
      final micStatus = await Permission.microphone.request();
      debugPrint('[VoiceIntakeService] Microphone permission status: $micStatus');
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        throw Exception('Microphone permission denied by user');
      }

      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        throw Exception('Audio recorder permission check failed');
      }

      // Stop previous recorder if running
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      // Configure 16 kHz mono PCM stream with voiceCommunication audio source and no focus pause
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        autoGain: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
          muteAudio: false,
        ),
      );

      final recordStream = await _audioRecorder.startStream(config);
      _micChunksSent = 0;
      _totalBytesSent = 0;

      debugPrint('[VoiceIntakeService] Microphone recording stream started (16kHz PCM16 Mono)');

      _micStreamSubscription = recordStream.listen(
        (data) {
          if (!_isConnected || _channel == null) return;

          _micChunksSent++;
          _totalBytesSent += data.length;

          if (_micChunksSent % 50 == 0) {
            debugPrint('[VoiceIntakeService] Streaming mic data: $_micChunksSent chunks, $_totalBytesSent bytes sent');
          }

          if (_isMuted) {
            final silence = Uint8List(data.length);
            _channel?.sink.add(silence);
          } else {
            _channel?.sink.add(data);
          }
        },
        onError: (e) {
          debugPrint('[VoiceIntakeService] Mic stream error: $e');
        },
        onDone: () {
          debugPrint('[VoiceIntakeService] Mic stream closed');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[VoiceIntakeService] Failed to start microphone: $e');
      rethrow;
    }
  }

  /// Buffer incoming 24 kHz audio chunks (§3.2)
  /// Strips redundant WAV headers from streaming chunks, then combines into seamless turn audio.
  void _onAudioChunkReceived(String base64Audio) {
    try {
      final trimmed = base64Audio.trim();
      if (trimmed.isEmpty) return;

      final bytes = base64Decode(trimmed);
      if (bytes.isEmpty) return;

      Uint8List pcmPayload;
      // Strip 44-byte RIFF header if present
      if (bytes.length >= 44 &&
          bytes[0] == 0x52 && // 'R'
          bytes[1] == 0x49 && // 'I'
          bytes[2] == 0x46 && // 'F'
          bytes[3] == 0x46) { // 'F'
        pcmPayload = bytes.sublist(44);
      } else {
        pcmPayload = bytes;
      }

      if (pcmPayload.isNotEmpty) {
        _turnPcmBuilder.add(pcmPayload);
      }

      // Schedule debounced playback if status: ready is delayed
      _turnPlaybackTimer?.cancel();
      _turnPlaybackTimer = Timer(const Duration(milliseconds: 350), () {
        _flushAndPlayTurnAudio();
      });
    } catch (e) {
      debugPrint('[VoiceIntakeService] Audio chunk buffering error: $e');
    }
  }

  /// Synthesize standard 44-byte RIFF WAV header for raw PCM16 samples
  Uint8List _createWavHeader(Uint8List pcmData, {required int sampleRate, required int numChannels}) {
    final int byteRate = sampleRate * numChannels * 2; // 16-bit = 2 bytes
    final int totalDataLen = pcmData.length + 36;
    final header = ByteData(44);

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, totalDataLen, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    header.setUint16(20, 1, Endian.little);  // AudioFormat 1 = PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, numChannels * 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample = 16

    // "data" sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, pcmData.length, Endian.little);

    final out = Uint8List(44 + pcmData.length);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, out.length, pcmData);
    return out;
  }

  /// Combine all buffered turn PCM frames into a single continuous WAV and play gaplessly
  void _flushAndPlayTurnAudio() async {
    _turnPlaybackTimer?.cancel();
    _turnPlaybackTimer = null;

    final pcmBytes = _turnPcmBuilder.takeBytes();
    if (pcmBytes.isEmpty) return;

    try {
      debugPrint('[VoiceIntakeService] Playing unified turn audio: ${pcmBytes.length} PCM bytes');
      final wavBytes = _createWavHeader(pcmBytes, sampleRate: 24000, numChannels: 1);
      _isPlaying = true;
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('[VoiceIntakeService] Error playing unified turn audio: $e');
    }
  }

  /// Stop any active speech playback (barge-in support)
  void stopAudioPlayback() {
    _turnPlaybackTimer?.cancel();
    _turnPlaybackTimer = null;
    _turnPcmBuilder.clear();
    try {
      _audioPlayer.stop();
    } catch (_) {}
    _isPlaying = false;
  }

  /// Teardown audio and close connection (§5.2)
  Future<void> disconnect() async {
    _isConnected = false;
    _turnPlaybackTimer?.cancel();
    _turnPlaybackTimer = null;
    _turnPcmBuilder.clear();
    _isPlaying = false;

    try {
      await _micStreamSubscription?.cancel();
      _micStreamSubscription = null;
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      await _channel?.sink.close();
      _channel = null;
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
