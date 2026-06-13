import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum ChatTemplate { qwen, llama }

class ModelDef {
  final String label;
  final String path;
  final ChatTemplate template;

  const ModelDef(this.label, this.path, this.template);
}

class ModelsConfig {
  static const useGpu = false;
  static const threads = 2;
  static const contextSize = 2048;
  static const port = 9090;

  static const models = [
    ModelDef('Qwen2.5 1.5B', '/storage/emulated/0/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf', ChatTemplate.qwen),
    ModelDef('Qwen2.5 Coder 1.5B', '/storage/emulated/0/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf', ChatTemplate.qwen),
    ModelDef('Qwen2.5 3B', '/storage/emulated/0/qwen2.5-3b-instruct-q4_k_m.gguf', ChatTemplate.qwen),
    ModelDef('Llama 3.2 1B (Q4)', '/storage/emulated/0/Llama-3.2-1B-Instruct-Q4_K_M.gguf', ChatTemplate.llama),
    ModelDef('Llama 3.2 1B (Q5)', '/storage/emulated/0/Llama-3.2-1B-Instruct-Q5_K_M.gguf', ChatTemplate.llama),
  ];
}

class ServerController {
  static const _channel = MethodChannel('llama_server');
  final ModelDef _modelDef;

  ServerController(this._modelDef);

  Future<void> start() async {
    final ok = await _channel.invokeMethod<bool>('startServer', {
      'modelPath': _modelDef.path,
      'port': ModelsConfig.port,
      'threads': ModelsConfig.threads,
      'contextSize': ModelsConfig.contextSize,
      'useGpu': ModelsConfig.useGpu,
    });
    if (ok != true) {
      throw Exception('Failed to start server: model not found or corrupt');
    }
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stopServer');
  }

  Future<bool> get isRunning async {
    return await _channel.invokeMethod('isRunning');
  }

  Future<bool> isRunningHttp() async {
    try {
      final resp = await http
          .get(Uri.parse('http://127.0.0.1:${ModelsConfig.port}/v1/models'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
