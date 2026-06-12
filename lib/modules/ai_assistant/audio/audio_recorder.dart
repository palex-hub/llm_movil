import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_config.dart';

class MicCapture {
  final _recorder = AudioRecorder();
  final AudioConfig _config;

  MicCapture({AudioConfig? config}) : _config = config ?? const AudioConfig();

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: _config.sampleRate,
        numChannels: _config.numChannels,
      ),
      path: path,
    );

    return path;
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
