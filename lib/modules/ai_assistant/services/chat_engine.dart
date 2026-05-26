import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_llama/flutter_llama.dart';

import '../audio/audio_model.dart';
import '../audio/audio_recorder.dart';
import 'chat_loop.dart';
import 'local_api_server.dart';
import '../models/react_event.dart';

class ChatEngine {
  final ChatLoop _loop = ChatLoop();
  final LocalApiServer _server = LocalApiServer();
  final AudioModel _audioModel = AudioModel();
  final MicCapture _audioRecorder = MicCapture();

  bool _initialized = false;
  bool _isRecording = false;

  bool get isReady => _initialized;
  bool get isRecording => _isRecording;
  AudioModel get audioModel => _audioModel;
  MicCapture get audioRecorder => _audioRecorder;

  Future<bool> init(String apiUrl) async {
    OpenAI.baseUrl = apiUrl;
    OpenAI.apiKey = 'sk-noop';
    OpenAI.requestsTimeOut = const Duration(minutes: 2);
    _server.registerAudioModel(_audioModel);
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

  Future<bool> initAudioModel(String modelPath) async {
    return await _audioModel.init(modelPath);
  }

  Future<bool> initLLMModel(String modelPath) async {
    final config = LlamaConfig(
      modelPath: modelPath,
      nGpuLayers: -1,
    );
    return await FlutterLlama.instance.loadModel(config);
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

    try {
      final response = await OpenAI.instance.audio.createTranscription(
        file: File(path),
        model: 'whisper-1',
        language: 'es',
      );
      return response.text;
    } catch (e) {
      return 'Error al transcribir: $e';
    }
  }

  Future<void> cancelMic() async {
    _isRecording = false;
    await _audioRecorder.cancelRecording();
  }

  Stream<ReActEvent> sendMessage(String text) {
    return _loop.processMessage(text);
  }

  void reset() {
    _loop.reset();
  }

  Future<void> dispose() async {
    _audioModel.dispose();
    await _audioRecorder.dispose();
    await _server.stop();
  }
}
