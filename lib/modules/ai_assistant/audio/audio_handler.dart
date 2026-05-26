import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';

import 'audio_model.dart';

Future<shelf.Response> handleAudioTranscription(
  shelf.Request request,
  AudioModel model,
) async {
  try {
    if (!request.isMultipart) {
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Se esperaba multipart/form-data'}),
        headers: {'content-type': 'application/json'},
      );
    }

    String? audioPath;

    await for (final formData in request.multipartFormData) {
      if (formData.name == 'file') {
        final bytes = await formData.part.readBytes();
        final tempDir = Directory.systemTemp;
        final tempFile = File(
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await tempFile.writeAsBytes(bytes);
        audioPath = tempFile.path;
      }
    }

    if (audioPath == null || !File(audioPath).existsSync()) {
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'No se encontro archivo de audio'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final text = await model.transcribe(audioPath);

    try {
      File(audioPath).delete();
    } catch (_) {}

    return shelf.Response.ok(
      jsonEncode({'text': text}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return shelf.Response.internalServerError(
      body: jsonEncode({'error': {'message': e.toString()}}),
      headers: {'content-type': 'application/json'},
    );
  }
}
