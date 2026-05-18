import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import '../models/react_event.dart';
import '../services/chat_engine.dart';
import '../services/llm_service.dart';
import '../services/permission_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ModelOption {
  final String name;
  final String path;
  const _ModelOption(this.name, this.path);
}

class _ChatScreenState extends State<ChatScreen> {
  final _engine = ChatEngine(LlmService());
  final List<types.Message> _messages = [];
  bool _loading = true;
  bool _modelReady = false;
  bool _generating = false;
  bool _switchingModel = false;
  StreamSubscription? _subscription;
  String _status = '';
  String _currentModel = '';

  static const _modelOptions = [
    _ModelOption('NeuralQwen 1.5B', PermissionService.modelPath1_5B),
    _ModelOption('Qwen2.5 3B', PermissionService.modelPath3B),
  ];

  @override
  void initState() {
    super.initState();
    _currentModel = _engine.currentModelPath;
    _initEngine();
  }

  Future<void> _initEngine() async {
    setState(() => _status = 'Solicitando permisos de almacenamiento...');
    final granted = await PermissionService.requestStoragePermission();
    if (!granted || !mounted) {
      if (mounted) setState(() { _loading = false; });
      _addSystemMsg('Permiso de almacenamiento denegado');
      return;
    }
    setState(() => _status = 'Cargando modelo de IA...');
    final ok = await _engine.loadModel();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _modelReady = true;
    } else {
      _addSystemMsg('Error: modelo no encontrado');
    }
  }

  Future<void> _onModelChanged(String path) async {
    if (path == _currentModel) return;
    setState(() {
      _switchingModel = true;
      _status = 'Cambiando modelo...';
    });
    final ok = await _engine.switchModel(path);
    if (!mounted) return;
    setState(() {
      _switchingModel = false;
      _modelReady = ok;
      _currentModel = path;
    });
    if (ok) {
      _addSystemMsg('Modelo cambiado a ${_modelOptions.firstWhere((m) => m.path == path).name}');
    } else {
      _addSystemMsg('Error al cargar el modelo');
    }
  }

  void _addSystemMsg(String text) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _messages.insert(0, types.TextMessage(
      author: const types.User(id: 'system', firstName: 'Sistema'),
      createdAt: now,
      id: 'sys_$now',
      text: text,
    )));
  }

  void _handleSend(types.PartialText partial) {
    if (_generating) return;
    if (!_modelReady) {
      _addSystemMsg('El modelo de IA no está cargado. Reinicia la app.');
      return;
    }
    setState(() => _generating = true);

    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = types.TextMessage(
      author: const types.User(id: 'user', firstName: 'You'),
      createdAt: now,
      id: now.toString(),
      text: partial.text,
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
    _subscription = _engine.sendMessage(partial.text).listen(
      (event) {
        if (event is ThoughtEvent) {
          buffer += 'Pensamiento: ${event.message}\n';
          _updateMsg(respId, buffer);
        } else if (event is ToolCallEvent) {
          buffer += 'Herramienta: ${event.tool}(${event.args})\n';
          _updateMsg(respId, buffer);
        } else if (event is ObservationEvent) {
          buffer += 'Resultado: ${event.observation}\n';
          _updateMsg(respId, buffer);
        } else if (event is AnswerTokenEvent) {
          buffer += event.text;
          _updateMsg(respId, buffer);
        } else if (event is ErrorEvent) {
          errored = true;
          _updateMsg(respId, 'Error: ${event.error}');
          setState(() => _generating = false);
        }
      },
      onError: (e) {
        errored = true;
        _updateMsg(respId, 'Error: $e');
        setState(() => _generating = false);
      },
      onDone: () {
        if (!errored) {
          _updateMsg(respId, buffer);
        }
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
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentModel,
                  isDense: true,
                  dropdownColor: Colors.deepPurple,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _modelOptions.map((m) => DropdownMenuItem(
                    value: m.path,
                    child: Text(m.name),
                  )).toList(),
                  onChanged: (_switchingModel || _generating) ? null : (path) {
                    if (path != null) _onModelChanged(path);
                  },
                ),
              ),
            ),
        ],
      ),
      body: _loading || _switchingModel
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(fontSize: 14)),
                ],
              ),
            )
          : Chat(
                  messages: _messages,
                  onSendPressed: _handleSend,
                  user: const types.User(id: 'user', firstName: 'You'),
                  theme: DefaultChatTheme(
                    primaryColor: Colors.deepPurple,
                    secondaryColor: const Color(0xFFE8E8E8),
                    inputBackgroundColor: Colors.white,
                    inputTextColor: Colors.black87,
                    backgroundColor: const Color(0xFFF5F5F5),
                    receivedMessageBodyTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    sentMessageBodyTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
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
