import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dart_openai/dart_openai.dart';

import '../models/react_event.dart';
import 'tool_definitions.dart';
import 'tool_executor.dart';

class ChatLoop {
  final ToolExecutor _executor = ToolExecutor();
  final List<OpenAIChatCompletionChoiceMessageModel> _history = [];
  final _seenSignatures = <String>{};

  void reset() {
    _history.clear();
    _seenSignatures.clear();
  }

  Stream<ReActEvent> processMessage(String text) async* {
    yield ThoughtEvent('Analizando...');
    _seenSignatures.clear();

    final messages = <OpenAIChatCompletionChoiceMessageModel>[
      ..._history,
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            'Objetivo: $text',
          ),
        ],
      ),
    ];

    int toolCalls = 0;
    const maxToolCalls = 5;

    while (toolCalls < maxToolCalls) {
      OpenAIChatCompletionModel response;
      try {
        response = await OpenAI.instance.chat.create(
          model: 'local',
          messages: messages,
          tools: ToolDefinition.toolsToOpenAI(),
          temperature: 0.1,
          maxTokens: 80,
        );
      } catch (e) {
        yield ErrorEvent('Error al generar: $e');
        return;
      }

      final choice = response.choices.first;
      final msg = choice.message;

      debugPrint('');
      debugPrint('== OPENAI RESPONSE ==');
      debugPrint('role: ${msg.role}');
      debugPrint('content: ${msg.content}');
      if (msg.toolCalls != null) {
        for (final tc in msg.toolCalls!) {
          debugPrint('tool_call: ${tc.function.name}(${tc.function.arguments})');
        }
      }
      debugPrint('=====================');

      if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
        final toolCall = msg.toolCalls!.first;
        final toolName = toolCall.function.name ?? '';
        final argsStr = toolCall.function.arguments;
        final args = argsStr is Map<String, dynamic>
            ? argsStr
            : (argsStr is String
                ? (jsonDecode(argsStr) as Map<String, dynamic>)
                : <String, dynamic>{});

        yield ToolCallEvent(toolName, args);

        final sig = '$toolName:${jsonEncode(args)}';
        if (toolName.startsWith('create_') && _seenSignatures.contains(sig)) {
          final obs =
              '[DUPLICADO] Esa accion ya se ejecuto antes. Pasa a la siguiente tarea.';
          yield ObservationEvent(obs);

          messages.add(OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.assistant,
            content: [],
          ));
          messages.add(RequestFunctionMessage(
            role: OpenAIChatMessageRole.tool,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(obs),
            ],
            toolCallId: toolCall.id ?? '',
          ));
          continue;
        }
        if (toolName.startsWith('create_')) _seenSignatures.add(sig);

        try {
          final observation = await _executor.execute(toolName, args);
          yield ObservationEvent(observation);

          messages.add(OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.assistant,
            content: [],
          ));
          messages.add(RequestFunctionMessage(
            role: OpenAIChatMessageRole.tool,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                observation,
              ),
            ],
            toolCallId: toolCall.id ?? '',
          ));
          toolCalls++;
        } catch (e) {
          yield ErrorEvent('Error al ejecutar $toolName: $e');
          return;
        }
      } else {
        final content = msg.content;
        if (content != null && content.isNotEmpty) {
          final answerText = content.map((c) => c.text ?? '').join();
          yield AnswerTokenEvent(answerText);
        }
        return;
      }
    }

    yield ErrorEvent('Demasiadas acciones, simplifica tu petición');
  }
}
