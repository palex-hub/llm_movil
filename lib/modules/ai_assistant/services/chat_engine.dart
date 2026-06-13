import 'dart:async';
import 'server_controller.dart';
import 'llama_chat.dart';

class ChatEngine {
  ServerController? _server;
  LlamaChat? _chat;
  bool _modelLoaded = false;
  ModelDef? _currentModel;
  int _modelLoadTimeMs = 0;

  bool get isModelLoaded => _modelLoaded;
  ModelDef? get currentModel => _currentModel;
  int get modelLoadTimeMs => _modelLoadTimeMs;
  GenerationParams get generationParams => _chat?.params ?? const GenerationParams();

  Future<void> startServer(ModelDef modelDef, {void Function(int elapsedMs)? onProgress}) async {
    final sw = Stopwatch()..start();
    _server = ServerController(modelDef);
    await _server!.start();
    while (!(await _server!.isRunning) && !(await _server!.isRunningHttp())) {
      await Future.delayed(const Duration(milliseconds: 200));
      onProgress?.call(sw.elapsedMilliseconds);
      if (sw.elapsedMilliseconds > 120000) {
        throw Exception('Timeout waiting for server');
      }
    }
    _modelLoadTimeMs = sw.elapsedMilliseconds;
    _chat = LlamaChat();
    _currentModel = modelDef;
    _modelLoaded = true;
  }

  Future<void> stopServer() async {
    if (!_modelLoaded) return;
    await _server!.stop();
    _currentModel = null;
    _modelLoaded = false;
  }

  Stream<GenerationChunk> sendMessage(String userMessage) {
    return _chat!.generateStream(userMessage: userMessage);
  }

  Future<void> dispose() async {
    await stopServer();
  }
}
