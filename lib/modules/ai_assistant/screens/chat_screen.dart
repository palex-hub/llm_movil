import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import '../models/react_event.dart';
import '../services/chat_engine.dart';
import '../services/llm_bridge.dart';
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
  bool _switchingModel = false;
  StreamSubscription? _subscription;
  bool _serverReady = false;
  bool _modelLoaded = false;
  int _chatKey = 0;

  static const _defaultModel = 'Qwen2.5 Coder 1.5B';
  String _currentModelLabel = _defaultModel;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() => _initializing = true);

    await _engine.init();
    final serverOk = await _engine.startServer();
    if (!mounted) return;

    if (!serverOk) {
      _addSystemMsg('Error al iniciar el servidor de audio');
      setState(() => _initializing = false);
      return;
    }

    final whisperOk = await _engine.initAudioModel();

    if (!mounted) return;

    if (!whisperOk) {
      _addSystemMsg(
        'Advertencia: Modelo Whisper no encontrado',
      );
    }

    _addSystemMsg('Cargando herramientas...');
    try {
      await _engine.fetchTools(
        'https://spkvgkwbfi.execute-api.us-east-1.amazonaws.com/dev/openapi.json',
      );
      _addSystemMsg('Herramientas cargadas');
    } catch (e) {
      _addSystemMsg('Advertencia: No se pudieron cargar herramientas: $e');
    }

    await _handleSwitchModel(_defaultModel);

    setState(() {
      _initializing = false;
      _serverReady = serverOk;
      _modelLoaded = true;
    });
  }

  Future<void> _handleSwitchModel(String label) async {
    if ((label == _currentModelLabel && _modelLoaded) || _switchingModel) return;
    setState(() => _switchingModel = true);
    _addSystemMsg('Cargando $label...');
    final info = LlmBridge.models[label]!;
    final ok = _modelLoaded
        ? await _engine.switchModel(info.path, info.variant)
        : await _engine.initLLMModel(info.path, info.variant);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _currentModelLabel = label;
        _modelLoaded = true;
      });
      _addSystemMsg('Modelo cargado: $label');
    } else {
      _addSystemMsg('Error: No se pudo cargar $label');
    }
    setState(() => _switchingModel = false);
  }

  void _addSystemMsg(String text) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _chatKey++;
      _messages.insert(
        0,
        types.TextMessage(
          author: const types.User(id: 'system', firstName: 'Sistema'),
          createdAt: now,
          id: 'sys_$now',
          text: text,
        ),
      );
    });
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
    if (!_modelLoaded) {
      _addSystemMsg('Primero selecciona un modelo del menú superior');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = types.TextMessage(
      author: const types.User(id: 'user', firstName: 'You'),
      createdAt: now,
      id: now.toString(),
      text: text,
    );
    final respId = 'resp_$now';
    final respMsg = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'AI'),
      createdAt: now + 1,
      id: respId,
      text: '',
    );
    setState(() {
      _generating = true;
      _chatKey++;
      _messages.insert(0, userMsg);
      _messages.insert(0, respMsg);
    });
    _subscription?.cancel();
    _subscription = _engine
        .sendMessage(text)
        .listen(
          (event) {
            if (event is AnswerTokenEvent) {
              _updateMsg(respId, event.text);
            } else if (event is ErrorEvent) {
              _updateMsg(respId, 'Error: ${event.error}');
              if (!mounted) return;
              setState(() => _generating = false);
            }
          },
          onError: (e) {
            _updateMsg(respId, 'Error: $e');
            if (!mounted) return;
            setState(() => _generating = false);
          },
          onDone: () {
            if (!mounted) return;
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
          Text('Iniciando...', style: TextStyle(fontSize: 14)),
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
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _currentModelLabel,
            isDense: true,
            isExpanded: false,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            items: LlmBridge.models.keys.map((label) {
              return DropdownMenuItem(
                value: label,
                child: Text(label, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _switchingModel || _generating ? null : (label) {
              if (label != null) _handleSwitchModel(label);
            },
          ),
        ),
      ),
      body: _initializing
          ? _buildLoading()
          : Chat(
              key: ValueKey(_chatKey),
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
