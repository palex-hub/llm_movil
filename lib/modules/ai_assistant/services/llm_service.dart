import 'package:flutter_llama/flutter_llama.dart';

class LlmService {
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<bool> init(String modelPath) async {
    if (_loaded) return true;
    return _load(modelPath);
  }

  Future<bool> switchModel(String modelPath) async {
    if (_loaded) {
      await FlutterLlama.instance.unloadModel();
      _loaded = false;
    }
    return _load(modelPath);
  }

  Future<bool> _load(String modelPath) async {
    final llama = FlutterLlama.instance;
    final config = LlamaConfig(
      modelPath: modelPath,
      contextSize: 1024,
      nThreads: 4,
      nGpuLayers: 99,
      useGpu: true,
      batchSize: 512,
    );

    final success = await llama.loadModel(config);
    if (success) _loaded = true;
    return success;
  }

  Future<String> generate(
    String prompt, {
    int maxTokens = 150,
    double temperature = 0.1,
    String? grammar,
  }) async {
    if (!_loaded) return 'Error: Model not loaded';

    final llama = FlutterLlama.instance;
    final response = await llama.generate(
      GenerationParams(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
        grammar: grammar,
      ),
    );
    return response.text;
  }

  Stream<String> generateStream(
    String prompt, {
    int maxTokens = 150,
    double temperature = 0.1,
  }) {
    if (!_loaded) return const Stream.empty();

    final llama = FlutterLlama.instance;
    return llama.generateStream(
      GenerationParams(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
      ),
    );
  }

  Future<void> dispose() async {
    if (!_loaded) return;
    await FlutterLlama.instance.unloadModel();
    _loaded = false;
  }
}
