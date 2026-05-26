import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import '../models/react_event.dart';
import '../services/chat_engine.dart';
import '../services/chat_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _engine = ChatEngine();
  final List<types.Message> _messages = [];
  final _inputController = TextEditingController();
  bool _initializing = true;
  bool _generating = false;
  bool _recording = false;
  StreamSubscription? _subscription;
  bool _serverReady = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() => _initializing = true);

    final serverOk = await _engine.startServer();
    if (!mounted) return;

    if (!serverOk) {
      _addSystemMsg('Error al iniciar el servidor local');
      setState(() => _initializing = false);
      return;
    }
    final ok = await _engine.init('http://127.0.0.1:8080');
    if (!mounted) return;

    const llmPath =
        '/storage/emulated/0/neuralqwen-2.5-1.5b-spanish.Q4_K_M.gguf';
    const whisperPath = '/storage/emulated/0/ggml-small.bin';

    final llmOk = await _engine.initLLMModel(llmPath);
    final whisperOk = await _engine.initAudioModel(whisperPath);

    if (!mounted) return;

    if (!llmOk) {
      _addSystemMsg('Error: Modelo LLM no encontrado en $llmPath');
    }
    if (!whisperOk) {
      _addSystemMsg(
        'Advertencia: Modelo Whisper no encontrado en $whisperPath',
      );
    }

    setState(() {
      _initializing = false;
      _serverReady = ok;
    });
  }

  void _addSystemMsg(String text) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(
      () => _messages.insert(
        0,
        types.TextMessage(
          author: const types.User(id: 'system', firstName: 'Sistema'),
          createdAt: now,
          id: 'sys_$now',
          text: text,
        ),
      ),
    );
  }

  Future<void> _handleStartRecording() async {
    if (_generating || !_serverReady) return;
    final ok = await _engine.startMic();
    if (!mounted) return;
    if (!ok) {
      _addSystemMsg('Error: Permiso de micrófono denegado');
      return;
    }
    setState(() => _recording = true);
  }

  Future<void> _handleStopRecording() async {
    setState(() => _recording = false);
    _addSystemMsg('Procesando audio...');
    final text = await _engine.stopMicAndTranscribe();
    if (!mounted) return;
    if (text.startsWith('Error:')) {
      _addSystemMsg(text);
      return;
    }
    _addSystemMsg('El texto es: $text');
    if (text.isNotEmpty) {
      _inputController.text = text;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    }
  }

  Future<void> _handleCancelMic() async {
    await _engine.cancelMic();
    if (!mounted) return;
    setState(() => _recording = false);
    _addSystemMsg('Grabación cancelada');
  }

  void _handleSendText(String text) {
    if (_generating) return;
    setState(() => _generating = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = types.TextMessage(
      author: const types.User(id: 'user', firstName: 'You'),
      createdAt: now,
      id: now.toString(),
      text: text,
    );
    setState(() => _messages.insert(0, userMsg));
    final respId = 'resp_$now';
    final respMsg = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'AI'),
      createdAt: now + 1,
      id: respId,
      text: '',
    );
    setState(() => _messages.insert(0, respMsg));
    String buffer = '';
    bool errored = false;
    _subscription?.cancel();
    _subscription = _engine
        .sendMessage(text)
        .listen(
          (event) {
            if (event is ThoughtEvent) {
              buffer += 'Pensamiento: ${event.message}\n';
            } else if (event is ToolCallEvent) {
              buffer += 'Herramienta: ${event.tool}(${event.args})\n';
            } else if (event is ObservationEvent) {
              buffer += 'Resultado: ${event.observation}\n';
            } else if (event is AnswerTokenEvent) {
              buffer += event.text;
            } else if (event is ErrorEvent) {
              errored = true;
              buffer = 'Error: ${event.error}';
            }
            _updateMsg(respId, buffer);
            if (event is ErrorEvent) setState(() => _generating = false);
          },
          onError: (e) {
            errored = true;
            _updateMsg(respId, 'Error: $e');
            setState(() => _generating = false);
          },
          onDone: () {
            if (!errored) _updateMsg(respId, buffer);
            setState(() => _generating = false);
          },
        );
  }

  void _updateMsg(String id, String text) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        _messages[idx] = types.TextMessage(
          author: const types.User(id: 'assistant', firstName: 'AI'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: id,
          text: text,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.dispose();
    _engine.dispose();
    super.dispose();
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Iniciando servidor local...', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      color: Colors.white,
      child: Row(
        children: [
          if (_recording) ...[
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _handleStopRecording,
              tooltip: 'Detener y transcribir',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _handleCancelMic,
              tooltip: 'Cancelar grabación',
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: false,
                decoration: const InputDecoration(
                  hintText: 'Grabando...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: _handleStartRecording,
              tooltip: 'Grabar audio',
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: InputBorder.none,
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) _handleSendText(text.trim());
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                final text = _inputController.text.trim();
                if (text.isNotEmpty) {
                  _inputController.clear();
                  _handleSendText(text);
                }
              },
              tooltip: 'Enviar',
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: _initializing
          ? _buildLoading()
          : Chat(
              messages: _messages,
              onSendPressed: (_) {},
              user: const types.User(id: 'user', firstName: 'You'),
              theme: chatTheme,
              customBottomWidget: _buildInputBar(),
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: _generating
                    ? [const types.User(id: 'assistant', firstName: 'AI')]
                    : [],
              ),
              showUserAvatars: true,
              showUserNames: true,
            ),
    );
  }
}
