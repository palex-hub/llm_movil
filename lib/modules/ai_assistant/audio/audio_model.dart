import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'audio_config.dart';

class AudioModel {
  Whisper? _whisper;
  late final AudioConfig _config;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  AudioModel({AudioConfig? config}) : _config = config ?? const AudioConfig();

  Future<bool> init() async {
    if (!File(_config.modelPath).existsSync()) {
      if (kDebugMode) {
        print('[AudioModel] Model not found: ${_config.modelPath}');
      }
      return false;
    }

    _whisper = Whisper(model: _config.whisperModel);
    _loaded = true;
    if (kDebugMode) {
      print('[AudioModel] Whisper model ready: ${_config.modelPath}');
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
          language: _config.language,
          isTranslate: false,
        ),
        modelPath: _config.modelPath,
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
    _whisper = null;
  }
}
