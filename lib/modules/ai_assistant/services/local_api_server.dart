import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'http_server.dart';
import 'llm_bridge.dart';

class LocalApiServer {
  final LlmBridge _bridge;
  final HttpServer _http = HttpServer();

  bool get isReady => _http.isReady;

  LocalApiServer(this._bridge);

  Future<void> start({int port = 8080}) async {
    _http.router.post('/v1/chat/completions', _handleChatCompletions);
    await _http.start(port: port);
  }

  Future<void> stop() async {
    await _http.stop();
  }

  Future<shelf.Response> _handleChatCompletions(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>? ?? [];

      String _extractContent(dynamic content) {
        if (content is String) return content;
        if (content is List) {
          return content
              .map((c) => (c is Map<String, dynamic>) ? (c['text'] as String? ?? '') : c.toString())
              .join();
        }
        return '';
      }

      String userMessage = '';
      String? systemPrompt;
      for (final msg in messages) {
        final role = msg['role'] as String?;
        if (role == 'user') {
          userMessage = _extractContent(msg['content']);
        } else if (role == 'system') {
          systemPrompt = _extractContent(msg['content']);
        }
      }

      final result = await _bridge.generate(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        maxTokens: body['max_tokens'] as int? ?? 150,
        temperature: (body['temperature'] as num?)?.toDouble() ?? 0.1,
      );

      final completion = {
        'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
        'object': 'chat.completion',
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'model': 'local-gguf',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': result,
            },
            'finish_reason': 'stop',
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
      debugPrint('XXXXXXXXXX LLM ERROR XXXXXXXXXX');
      debugPrint('$e');
      debugPrint('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': {'message': e.toString()}}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
