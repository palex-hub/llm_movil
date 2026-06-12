import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';

import '../models/react_event.dart';
import 'tool_service.dart';

class ChatLoop {
  ToolService? _toolService;

  void setTools(ToolService service) {
    _toolService = service;
  }

  Stream<ReActEvent> processMessage(String text) async* {
    final stopwatch = Stopwatch()..start();

    const systemMsg = 'Eres un asistente útil. Responde siempre en español. Usa solo los datos que el usuario te dio, no inventes nada.';

    final conversation = StringBuffer();
    conversation.writeln('$text\n\nImportante: usa solo los datos que te di. No inventes nada.');
    conversation.writeln();

    String? prevToolSig;
    String? lastGoodResult;

    for (var i = 0; i < 5; i++) {
      final messages = [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(systemMsg),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(conversation.toString()),
          ],
        ),
      ];

      final response = await OpenAI.instance.chat.create(
        model: 'local',
        messages: messages,
        temperature: 0.1,
        maxTokens: 300,
      );

      final content = response.choices.first.message.content;
      final answer = content?.map((c) => c.text ?? '').join() ?? '';

      debugPrint('');
      debugPrint('---------- LLM RAW RESPONSE ----------');
      debugPrint(answer);
      debugPrint('--------------------------------------');

      final toolCalls = ToolService.parseToolCalls(answer);
      final currentSig = toolCalls.isNotEmpty ? jsonEncode(toolCalls) : null;
      if (currentSig != null && currentSig == prevToolSig) {
        if (lastGoodResult != null) {
          yield AnswerTokenEvent(lastGoodResult);
        } else {
          yield AnswerTokenEvent('No pude completar la operación. Los datos enviados no son válidos.');
        }
        return;
      }
      prevToolSig = currentSig;

      if (toolCalls.isNotEmpty && _toolService != null) {
        // Check for finalizar - escape tool
        final finalizar = toolCalls.where((tc) => tc['name'] == 'finalizar').firstOrNull;
        if (finalizar != null) {
          final msg = (finalizar['arguments'] as Map<String, dynamic>)['mensaje'] as String? ?? '';
          stopwatch.stop();
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          final now = DateTime.now();
          final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          yield AnswerTokenEvent('$msg\n\n🕐 $time (⏱ ${elapsed.toStringAsFixed(2)}s)');
          return;
        }

        var allOk = true;
        for (final tc in toolCalls) {
          final toolName = tc['name'] as String;
          final args = tc['arguments'] as Map<String, dynamic>;
          yield ToolRunEvent(toolName, args);

          final result = await _toolService!.executeTool(toolName, args);
          yield ToolResultEvent(toolName, result);
          final truncatedResult = result.length > 200 ? '${result.substring(0, 200)}...' : result;
          conversation.writeln('Resultado de $toolName: $truncatedResult');
          if (result.startsWith('Error')) {
            allOk = false;
          } else {
            lastGoodResult = truncatedResult;
          }
        }

        conversation.writeln();
        if (allOk) {
          conversation.writeln('Éxito. No llames la misma herramienta. Responde al usuario.');
        } else {
          conversation.writeln('Error. Si ya lo intentaste antes, usa finalizar. No repitas la misma herramienta.');
        }

        if (conversation.length > 800) {
          final full = conversation.toString();
          conversation.clear();
          conversation.write('...(historial anterior omitido)...\n');
          conversation.write(full.substring(full.length - 600));
        }
        continue;
      }

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
      final now = DateTime.now();
      final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      yield AnswerTokenEvent('$answer\n\n🕐 $time (⏱ ${elapsed.toStringAsFixed(2)}s)');
      return;
    }

    yield ErrorEvent('Error: Demasiadas iteraciones de herramientas');
  }
}
