import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../audio/audio_handler.dart';
import '../audio/audio_model.dart';
import 'tool_definitions.dart';

class LocalApiServer {
  HttpServer? _server;
  bool _ready = false;
  AudioModel? _audioModel;

  bool get isReady => _ready;

  void registerAudioModel(AudioModel model) {
    _audioModel = model;
  }

  Future<void> start({int port = 8080}) async {
    final app = Router();

    app.post('/v1/chat/completions', _handleChatCompletions);
    app.post('/v1/audio/transcriptions', _handleAudioTranscriptions);

    _server = await shelf_io.serve(
      shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(app),
      InternetAddress.loopbackIPv4,
      port,
    );

    _ready = true;
    if (kDebugMode) {
      print('[LocalApiServer] Running on http://127.0.0.1:$port/v1');
    }
  }

  Future<void> stop() async {
    _ready = false;
    await _server?.close();
    _server = null;
  }

  Future<shelf.Response> _handleChatCompletions(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final tools = body['tools'] as List<dynamic>?;

      final prompt = _buildPrompt(messages, tools);

      final llama = FlutterLlama.instance;
      final response = await llama.generate(
        GenerationParams(
          prompt: prompt,
          maxTokens: body['max_tokens'] as int? ?? 150,
          temperature: (body['temperature'] as num?)?.toDouble() ?? 0.1,
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

      final parsed = _parseToolCall(response.text);

      final message = <String, dynamic>{'role': 'assistant'};
      if (parsed != null) {
        message.addAll(parsed);
      } else {
        message['content'] = response.text;
      }

      final completion = {
        'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
        'object': 'chat.completion',
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'model': 'local-gguf',
        'choices': [
          {
            'index': 0,
            'message': message,
            'finish_reason': parsed != null ? 'tool_calls' : 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 0,
          'completion_tokens': 0,
          'total_tokens': 0,
        },
      };

      return shelf.Response.ok(
        jsonEncode(completion),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      debugPrint('');
      debugPrint('XXXXXXXXXX LLM ERROR XXXXXXXXXX');
      debugPrint('$e');
      debugPrint('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': {'message': e.toString()}}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<shelf.Response> _handleAudioTranscriptions(shelf.Request request) async {
    if (_audioModel == null) {
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Audio model not initialized'}),
        headers: {'content-type': 'application/json'},
      );
    }
    return handleAudioTranscription(request, _audioModel!);
  }

  String _buildPrompt(List<dynamic> messages, List<dynamic>? tools) {
    final buf = StringBuffer();
    buf.writeln('<|im_start|>system');
    buf.writeln(ToolDefinition.systemPrompt);
    buf.writeln('<|im_end|>');

    for (final msg in messages) {
      final role = msg['role'] as String;
      final raw = msg['content'];
      String contentStr;
      if (raw is String) {
        contentStr = raw;
      } else if (raw is List) {
        contentStr = raw.map((c) => (c['text'] as String?) ?? '').join('\n');
      } else {
        contentStr = '';
      }
      if (role == 'system') continue;

      if (role == 'tool') {
        final toolCallId = msg['tool_call_id'] as String?;
        buf.writeln('<|im_start|>function_result');
        if (toolCallId != null) buf.writeln('tool_call_id: $toolCallId');
        buf.writeln(contentStr);
        buf.writeln('<|im_end|>');
      } else {
        buf.writeln('<|im_start|>$role');
        buf.writeln(contentStr);
        buf.writeln('<|im_end|>');
      }
    }

    buf.writeln('<|im_start|>assistant');
    return buf.toString();
  }

  Map<String, dynamic>? _parseToolCall(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('answer:')) {
      return {'content': trimmed.substring(7).trim()};
    }
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end < start) return null;
      final json = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;

      if (json['tool'] != null) {
        return {
          'content': null,
          'tool_calls': [
            {
              'id': 'call_${DateTime.now().millisecondsSinceEpoch}',
              'type': 'function',
              'function': {
                'name': json['tool'],
                'arguments': jsonEncode(json['args'] ?? {}),
              },
            },
          ],
        };
      }

      if (json['answer'] != null) {
        return {'content': json['answer'] as String};
      }

      return {'content': text};
    } catch (_) {
      return {'content': text};
    }
  }
}
