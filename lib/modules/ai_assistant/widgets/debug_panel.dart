import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../services/llama_chat.dart';

class DebugPanel extends StatelessWidget {
  final String modelLabel;
  final bool isRunning;
  final int modelLoadTimeMs;
  final String? lastInputText;
  final String? lastOutputText;
  final GenerationMetrics? lastMetrics;
  final GenerationParams? lastParams;

  const DebugPanel({
    super.key,
    required this.modelLabel,
    required this.isRunning,
    required this.modelLoadTimeMs,
    this.lastInputText,
    this.lastOutputText,
    this.lastMetrics,
    this.lastParams,
  });

  String _ms(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';

  String _tokPerSec(int tokens, int ms) {
    if (ms <= 0) return '—';
    return '${(tokens / (ms / 1000.0)).toStringAsFixed(1)} tok/s';
  }

  String _truncate(String? text, int max) {
    if (text == null || text.isEmpty) return '—';
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = lastMetrics;
    final p = lastParams;
    return Container(
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFCDD6F4),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            if (p != null) ...[
              const SizedBox(height: 2),
              _paramsLine(p),
            ],
            const SizedBox(height: 4),
            _inputSection(metrics),
            if (metrics != null) ...[
              const SizedBox(height: 2),
              _outputSection(metrics),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final status = isRunning ? '✅' : '⏸';
    return Row(
      children: [
        Text('▸ $modelLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(status, style: const TextStyle(fontSize: 10)),
        if (modelLoadTimeMs > 0) ...[
          const SizedBox(width: 8),
          Text('carga ${_ms(modelLoadTimeMs)}'),
        ],
        const Spacer(),
        Text('GPU:${ModelsConfig.useGpu ? "ON" : "OFF"} T:${ModelsConfig.threads} ctx:${ModelsConfig.contextSize}'),
      ],
    );
  }

  Widget _paramsLine(GenerationParams p) {
    return Text(
      'T:${p.temperature}  maxTok:${p.maxTokens}  '
      'topP:${p.topP}  topK:${p.topK}  rep:${p.repeatPenalty}',
      style: const TextStyle(color: Color(0xFF6C7086), fontSize: 10),
    );
  }

  Widget _inputSection(GenerationMetrics? metrics) {
    final inputTok = metrics?.promptTokens ?? 0;
    final prefillMs = metrics?.timeToFirstTokenMs ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('IN  ', style: TextStyle(color: Color(0xFF89B4FA))),
        Expanded(
          child: Text(
            _truncate(lastInputText, 80),
            style: const TextStyle(color: Color(0xFFA6E3A1)),
          ),
        ),
        if (metrics != null) ...[
          const SizedBox(width: 8),
          Text('$inputTok tok • ${_ms(prefillMs)} • ${_tokPerSec(inputTok, prefillMs)}'),
        ],
      ],
    );
  }

  Widget _outputSection(GenerationMetrics metrics) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OUT ', style: TextStyle(color: Color(0xFFF9E2AF))),
        Expanded(
          child: Text(
            _truncate(lastOutputText, 80),
            style: const TextStyle(color: Color(0xFFBAC2DE)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${metrics.completionTokens} tok • '
          '${_ms(metrics.outputTimeMs)} • '
          '${_tokPerSec(metrics.completionTokens, metrics.outputTimeMs)}',
        ),
      ],
    );
  }
}
