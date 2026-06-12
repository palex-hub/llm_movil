import 'package:whisper_ggml/whisper_ggml.dart';

class AudioConfig {
  final String modelPath;
  final String language;
  final int sampleRate;
  final int numChannels;
  final WhisperModel whisperModel;

  const AudioConfig({
    this.modelPath = '/storage/emulated/0/ggml-tiny.bin',
    this.language = 'es',
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.whisperModel = WhisperModel.tiny,
  });
}
