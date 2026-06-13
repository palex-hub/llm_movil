import 'dart:async';
import 'package:dart_openai/dart_openai.dart';
import 'server_controller.dart';

class GenerationParams {
  final double temperature;
  final int maxTokens;
  final double topP;
  final int topK;
  final double repeatPenalty;

  const GenerationParams({
    this.temperature = 0.1,
    this.maxTokens = 150,
    this.topP = 0.9,
    this.topK = 40,
    this.repeatPenalty = 1.1,
  });
}

class GenerationMetrics {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int generationTimeMs;
  final int timeToFirstTokenMs;
  final int outputTimeMs;
  final double tokensPerSecond;

  GenerationMetrics({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.generationTimeMs,
    required this.timeToFirstTokenMs,
  })  : outputTimeMs = generationTimeMs - timeToFirstTokenMs,
        tokensPerSecond = generationTimeMs > 0
            ? completionTokens / (generationTimeMs / 1000.0)
            : 0.0;
}

class GenerationChunk {
  final String token;
  final bool isComplete;
  final String fullText;
  final GenerationMetrics? metrics;

  GenerationChunk({
    required this.token,
    required this.isComplete,
    required this.fullText,
    this.metrics,
  });
}

class LlamaChat {
  GenerationParams params = const GenerationParams();

  LlamaChat() {
    OpenAI.baseUrl = 'http://127.0.0.1:${ModelsConfig.port}';
    OpenAI.apiKey = 'sk-no-key-required';
  }

  Stream<GenerationChunk> generateStream({
    required String userMessage,
    String? systemPrompt,
  }) async* {
    final messages = <OpenAIChatCompletionChoiceMessageModel>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
          ],
        ),
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(userMessage),
        ],
      ),
    ];

    int promptTokenCount = 0;
    for (final msg in messages) {
      final items = msg.content;
      if (items == null) continue;
      for (final item in items) {
        final text = item.text;
        if (text == null) continue;
        promptTokenCount += (text.length + 3) ~/ 4;
      }
    }

    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    int completionTokens = 0;
    int timeToFirstTokenMs = 0;
    bool firstTokenSeen = false;

    final stream = OpenAI.instance.chat.createStream(
      model: 'default',
      messages: messages,
      temperature: params.temperature,
      maxTokens: params.maxTokens,
      topP: params.topP,
    );

    await for (final event in stream) {
      for (final choice in event.choices) {
        if (!choice.delta.haveContent) continue;
        for (final item in choice.delta.content ?? []) {
          final text = item?.text ?? '';
          if (text.isEmpty) continue;
          if (!firstTokenSeen) {
            timeToFirstTokenMs = stopwatch.elapsedMilliseconds;
            firstTokenSeen = true;
          }
          completionTokens++;
          buffer.write(text);
          yield GenerationChunk(
            token: text,
            isComplete: false,
            fullText: buffer.toString(),
          );
        }
      }
    }

    stopwatch.stop();

    final metrics = GenerationMetrics(
      promptTokens: promptTokenCount,
      completionTokens: completionTokens,
      totalTokens: promptTokenCount + completionTokens,
      generationTimeMs: stopwatch.elapsedMilliseconds,
      timeToFirstTokenMs: timeToFirstTokenMs,
    );

    yield GenerationChunk(
      token: '',
      isComplete: true,
      fullText: buffer.toString(),
      metrics: metrics,
    );
  }

  Future<String> generate({
    required String userMessage,
    String? systemPrompt,
  }) async {
    final messages = <OpenAIChatCompletionChoiceMessageModel>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
          ],
        ),
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(userMessage),
        ],
      ),
    ];

    final result = await OpenAI.instance.chat.create(
      model: 'default',
      messages: messages,
      temperature: params.temperature,
      maxTokens: params.maxTokens,
    );
    final content = result.choices.first.message.content;
    final text = content != null && content.isNotEmpty ? content.first.text : null;
    return text ?? '';
  }
}
