import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class MicCapture {
  final _recorder = AudioRecorder();

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
        sampleRate: 16000,
        numChannels: 1,
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
