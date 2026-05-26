import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class AudioModel {
  bool _loaded = false;
  bool _initialized = false;
  String? _modelPath;
  Whisper? _whisper;

  bool get isLoaded => _loaded;
  bool get isInitialized => _initialized;

  Future<bool> init(String modelPath) async {
    _modelPath = modelPath;
    _whisper = const Whisper(model: WhisperModel.small);

    if (!File(modelPath).existsSync()) {
      if (kDebugMode) {
        print('[AudioModel] Model not found: $modelPath');
      }
      return false;
    }

    _loaded = true;
    _initialized = true;
    if (kDebugMode) {
      print('[AudioModel] Whisper model ready: $modelPath');
    }
    return true;
  }

  Future<String> transcribe(String audioPath) async {
    if (!_loaded || _whisper == null) {
      return 'Error: Modelo de audio no cargado';
    }

    try {
      final response = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: 'es',
          isTranslate: false,
        ),
        modelPath: _modelPath!,
      );

      return response.text;
    } catch (e) {
      if (kDebugMode) {
        print('[AudioModel] Transcription error: $e');
      }
      return 'Error al transcribir: $e';
    }
  }

  void dispose() {
    _loaded = false;
    _initialized = false;
    _whisper = null;
    _modelPath = null;
  }
}
