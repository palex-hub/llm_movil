import 'dart:convert';
import '../models/react_event.dart';
import 'llm_service.dart';
import 'tool_definitions.dart';
import 'tool_executor.dart';

class ReactEngine {
  final LlmService _llm;
  final ToolExecutor _executor = ToolExecutor();
  final List<String> _completed = [];
  final _seenSignatures = <String>{};

  static const String _grammar = r'''root ::= tool-call | answer
tool-call ::= "{" ws "\"thought\"" ws ":" ws string ws "," ws "\"tool\"" ws ":" ws string ws "," ws "\"args\"" ws ":" ws value ws "}"
answer ::= "{" ws "\"thought\"" ws ":" ws string ws "," ws "\"answer\"" ws ":" ws string ws "}"
value ::= string | number | object | array | "true" | "false" | "null"
object ::= "{" ws (pair ("," ws pair)*)? ws "}"
pair ::= string ws ":" ws value
array ::= "[" ws (value ("," ws value)*)? ws "]"
string ::= "\"" char* "\""
char ::= [^"\\] | "\\" .
number ::= "-"? ("0" | [1-9] [0-9]*) ("." [0-9]+)?
ws ::= [ \t]*
''';

  ReactEngine(this._llm);

  Stream<ReActEvent> processMessage(String message) async* {
    yield ThoughtEvent('Analizando...');
    _completed.clear();
    _seenSignatures.clear();

    int toolCalls = 0;
    const maxToolCalls = 5;

    while (toolCalls < maxToolCalls) {
      final prompt = _buildPrompt(message);
      print(prompt);
      final response = await _safeGenerate(prompt, toolCalls == 0 ? 60 : 80);
      if (response == null) {
        yield ErrorEvent('Error al generar respuesta');
        return;
      }

      final json = _parseJson(response);

      if (json != null && json['tool'] != null) {
        final thought = json['thought'] as String?;
        if (thought != null && thought.isNotEmpty) yield ThoughtEvent(thought);

        final tool = json['tool'] as String;
        final args = json['args'] as Map<String, dynamic>? ?? {};
        yield ToolCallEvent(tool, args);

        final sig = '$tool:${jsonEncode(args)}';
        if (tool.startsWith('create_') && _seenSignatures.contains(sig)) {
          yield ObservationEvent('[DUPLICADO] Esa accion ya se ejecuto antes. Pasa a la siguiente tarea.');
          _completed.add('[DUPLICADO] $tool ya ejecutado');
          continue;
        }
        if (tool.startsWith('create_')) _seenSignatures.add(sig);

        try {
          final observation = await _executor.execute(tool, args);
          yield ObservationEvent(observation);

          _completed.add(observation);
          toolCalls++;
        } catch (e) {
          yield ErrorEvent('Error al ejecutar $tool: $e');
          return;
        }
      } else if (json != null && json['answer'] != null) {
        final thought = json['thought'] as String?;
        if (thought != null && thought.isNotEmpty) yield ThoughtEvent(thought);

        final answer = json['answer'] as String;
        yield AnswerTokenEvent(answer);
        return;
      } else {
        yield AnswerTokenEvent(response);
        return;
      }
    }

    yield ErrorEvent('Demasiadas acciones, simplifica tu petición');
  }

  String _buildPrompt(String message) {
    final buf = StringBuffer();
    buf.writeln('<|im_start|>system');
    buf.writeln(ToolDefinition.systemPrompt);
    buf.writeln('<|im_end|>\n<|im_start|>user');
    buf.writeln('Objetivo: $message\n');

    if (_completed.isNotEmpty) {
      buf.writeln('Hecho:');
      for (final c in _completed) {
        buf.writeln(c);
      }
      buf.writeln(
        '\nRegla: NO repitas lo Hecho. Ejecuta SOLO el paso faltante del Objetivo.',
      );
      buf.writeln(
        'Si ya se completó el Objetivo entero, responde solo: answer',
      );
    } else {
      buf.writeln('Ejecuta el primer paso del Objetivo.');
    }

    buf.writeln('<|im_end|>\n<|im_start|>assistant');
    return buf.toString();
  }

  Future<String?> _safeGenerate(String prompt, int maxTokens) async {
    try {
      return await _llm.generate(
        prompt,
        maxTokens: maxTokens,
        temperature: 0.1,
        grammar: _grammar,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end < start) return null;
      return jsonDecode(text.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _completed.clear();
    _seenSignatures.clear();
  }

  Future<void> dispose() => _llm.dispose();
}
