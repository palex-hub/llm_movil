import 'package:flutter/foundation.dart';
import 'package:dart_openai/dart_openai.dart';

import '../audio/audio_config.dart';
import '../audio/audio_model.dart';
import '../audio/audio_recorder.dart';
import 'chat_loop.dart';
import 'local_api_server.dart';
import 'llm_bridge.dart';
import 'tool_service.dart';
import '../models/react_event.dart';

class ChatEngine {
  final LlmBridge _bridge = LlmBridge();
  late final LocalApiServer _server = LocalApiServer(_bridge);
  final ChatLoop _loop = ChatLoop();
  final AudioModel _audioModel;
  final MicCapture _audioRecorder;
  ToolService? _toolService;

  bool _initialized = false;
  bool _isRecording = false;

  bool get isReady => _initialized;
  bool get isRecording => _isRecording;
  AudioModel get audioModel => _audioModel;
  MicCapture get audioRecorder => _audioRecorder;
  LlmBridge get bridge => _bridge;
  ToolService? get toolService => _toolService;

  ChatEngine({AudioConfig? config})
      : _audioModel = AudioModel(config: config),
        _audioRecorder = MicCapture(config: config);

  Future<void> fetchTools(String specUrl) async {
    _toolService = ToolService(specUrl: specUrl);
    await _toolService!.fetchTools();
    _loop.setTools(_toolService!);
    final systemPrompt = _toolService!.buildSystemPrompt(null);
    _bridge.cacheSystemPrompt(systemPrompt);
  }

  Future<bool> init({String apiUrl = 'http://127.0.0.1:8080'}) async {
    OpenAI.baseUrl = apiUrl;
    OpenAI.apiKey = 'sk-noop';
    OpenAI.requestsTimeOut = const Duration(minutes: 2);
    _initialized = true;
    return true;
  }

  Future<bool> startServer({int port = 8080}) async {
    await _server.start(port: port);
    return _server.isReady;
  }

  Future<void> stopServer() async {
    await _server.stop();
  }

  Future<bool> initAudioModel() async {
    return await _audioModel.init();
  }

  Future<bool> initLLMModel(String modelPath, ModelVariant variant) async {
    return await _bridge.load(modelPath, variant);
  }

  Future<bool> switchModel(String modelPath, ModelVariant variant) async {
    return await _bridge.switchModel(modelPath, variant);
  }

  Future<bool> startMic() async {
    final hasPermission = await _audioRecorder.requestPermission();
    if (!hasPermission) return false;

    await _audioRecorder.startRecording();
    _isRecording = true;
    return true;
  }

  Future<String> stopMicAndTranscribe() async {
    _isRecording = false;
    final path = await _audioRecorder.stopRecording();

    if (path == null) return 'Error: No se pudo grabar audio';

    debugPrint('[Audio] Recording saved: $path');

    return await _audioModel.transcribe(path);
  }

  Future<void> cancelMic() async {
    _isRecording = false;
    await _audioRecorder.cancelRecording();
  }

  Stream<ReActEvent> sendMessage(String text) {
    return _loop.processMessage(text);
  }

  Future<void> dispose() async {
    _audioModel.dispose();
    await _audioRecorder.dispose();
    await _bridge.dispose();
    await _server.stop();
  }
}
