import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';

enum ModelVariant { qwen, llama }

class ModelInfo {
  final String path;
  final ModelVariant variant;
  const ModelInfo(this.path, this.variant);
}

class LlmBridge {
  ModelVariant _variant = ModelVariant.qwen;
  bool _loaded = false;
  String? _cachedSystemPrompt;

  bool get isLoaded => _loaded;
  ModelVariant get variant => _variant;

  void cacheSystemPrompt(String text) {
    _cachedSystemPrompt = text;
  }

  static const Map<String, ModelInfo> models = {
    'Qwen2.5 1.5B': ModelInfo(
      '/storage/emulated/0/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
      ModelVariant.qwen,
    ),
    'Qwen2.5 Coder 1.5B': ModelInfo(
      '/storage/emulated/0/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
      ModelVariant.qwen,
    ),
    'Qwen2.5 3B': ModelInfo(
      '/storage/emulated/0/qwen2.5-3b-instruct-q4_k_m.gguf',
      ModelVariant.qwen,
    ),
    'Llama 3.2 1B (Q4)': ModelInfo(
      '/storage/emulated/0/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      ModelVariant.llama,
    ),
    'Llama 3.2 1B (Q5)': ModelInfo(
      '/storage/emulated/0/Llama-3.2-1B-Instruct-Q5_K_M.gguf',
      ModelVariant.llama,
    ),
  };

  static String _buildUserPrompt(ModelVariant variant, String user) {
    final buf = StringBuffer();
    switch (variant) {
      case ModelVariant.qwen:
        buf.writeln('<|im_start|>user');
        buf.writeln(user);
        buf.writeln('<|im_end|>');
        buf.write('<|im_start|>assistant');
      case ModelVariant.llama:
        buf.write('<|start_header_id|>user<|end_header_id|>\n\n');
        buf.writeln(user);
        buf.write('<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n');
    }
    return buf.toString();
  }

  static String _buildPrompt(ModelVariant variant, String? system, String user) {
    final buf = StringBuffer();
    switch (variant) {
      case ModelVariant.qwen:
        if (system != null && system.isNotEmpty) {
          buf.writeln('<|im_start|>system');
          buf.writeln(system);
          buf.writeln('<|im_end|>');
        }
        buf.writeln('<|im_start|>user');
        buf.writeln(user);
        buf.writeln('<|im_end|>');
        buf.write('<|im_start|>assistant');
      case ModelVariant.llama:
        buf.write('<|begin_of_text|>');
        if (system != null && system.isNotEmpty) {
          buf.write('<|start_header_id|>system<|end_header_id|>\n\n');
          buf.writeln(system);
          buf.write('<|eot_id|>');
        }
        buf.write('<|start_header_id|>user<|end_header_id|>\n\n');
        buf.writeln(user);
        buf.write('<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n');
    }
    return buf.toString();
  }

  Future<bool> load(String modelPath, ModelVariant variant) async {
    _variant = variant;
    final config = LlamaConfig(
      modelPath: modelPath,
      nGpuLayers: 0,
      nThreads: 2,
      contextSize: 2048,
      batchSize: 512,
      useGpu: false,
    );
    _loaded = await FlutterLlama.instance.loadModel(config);
    if (_loaded && _cachedSystemPrompt != null) {
      await FlutterLlama.instance.setPrePrompt(_cachedSystemPrompt!);
    }
    return _loaded;
  }

  Future<bool> switchModel(String modelPath, ModelVariant variant) async {
    await FlutterLlama.instance.unloadModel();
    return await load(modelPath, variant);
  }

  Future<String> generate({
    required String userMessage,
    String? systemPrompt,
    int maxTokens = 150,
    double temperature = 0.1,
  }) async {
    if (!_loaded) return 'Error: Modelo no cargado';

    final prompt = _buildUserPrompt(_variant, userMessage);

    final response = await FlutterLlama.instance.generate(
      GenerationParams(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
      ),
    );

    debugPrint('');
    debugPrint('---------- LLM RESPONSE ----------');
    debugPrint(response.text);
    debugPrint('tokens: ${response.tokensGenerated} | ${response.generationTimeMs}ms');
    debugPrint('----------------------------------');

    return response.text;
  }

  Future<void> dispose() async {
    await FlutterLlama.instance.unloadModel();
    _loaded = false;
  }
}
