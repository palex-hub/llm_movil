import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import '../services/chat_engine.dart';
import '../services/chat_theme.dart';
import '../services/server_controller.dart';
import '../services/llama_chat.dart';
import '../widgets/debug_panel.dart';

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
  int _loadTimeMs = 0;
  StreamSubscription? _subscription;
  int _chatKey = 0;

  String _currentModelLabel = ModelsConfig.models.first.label;

  String _lastInputText = '';
  String _lastOutputText = '';
  GenerationMetrics? _lastMetrics;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() {
      _initializing = true;
      _loadTimeMs = 0;
    });
    await _handleSwitchModel(_currentModelLabel);
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _handleSwitchModel(String label) async {
    if (label == _currentModelLabel && _engine.isModelLoaded || _generating) return;
    setState(() {
      _generating = true;
      _loadTimeMs = 0;
    });
    _addSystemMsg('Iniciando $label...');
    await _engine.stopServer();
    final def = ModelsConfig.models.firstWhere((m) => m.label == label);
    try {
      await _engine.startServer(def, onProgress: (ms) {
        if (!mounted) return;
        setState(() => _loadTimeMs = ms);
      });
      if (!mounted) return;
      setState(() {
        _currentModelLabel = label;
      });
      _addSystemMsg('$label listo');
    } catch (e) {
      if (!mounted) return;
      _addSystemMsg('Error al iniciar $label: $e');
    }
    setState(() => _generating = false);
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

  void _handleSendText(String text) {
    if (_generating || !_engine.isModelLoaded) return;
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
      _lastInputText = text;
      _lastOutputText = '';
      _lastMetrics = null;
    });
    _subscription?.cancel();
    _subscription = _engine.sendMessage(text).listen(
      (chunk) {
        if (chunk.isComplete) {
          _updateMsg(respId, chunk.fullText);
          if (!mounted) return;
          setState(() {
            _generating = false;
            _lastOutputText = chunk.fullText;
            _lastMetrics = chunk.metrics;
          });
        } else {
          _appendToken(respId, chunk.token);
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

  void _appendToken(String id, String token) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        final current = _messages[idx] as types.TextMessage;
        _messages[idx] = types.TextMessage(
          author: const types.User(id: 'assistant', firstName: 'AI'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: id,
          text: current.text + token,
        );
      }
    });
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
    final secs = _loadTimeMs ~/ 1000;
    final msg = secs > 0 ? 'Iniciando... ${secs}s' : 'Iniciando...';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(fontSize: 14)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _initializing
            ? const Text('AI Assistant')
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentModelLabel,
                  isDense: true,
                  isExpanded: false,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  items: ModelsConfig.models.map((m) {
                    return DropdownMenuItem(
                      value: m.label,
                      child: Text(m.label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _generating ? null : (label) {
                    if (label != null) _handleSwitchModel(label);
                  },
                ),
              ),
      ),
      body: _initializing
          ? _buildLoading()
          : Column(
              children: [
                DebugPanel(
                  modelLabel: _currentModelLabel,
                  isRunning: _engine.isModelLoaded,
                  modelLoadTimeMs: _engine.modelLoadTimeMs,
                  lastInputText: _lastInputText,
                  lastOutputText: _lastOutputText,
                  lastMetrics: _lastMetrics,
                  lastParams: _engine.generationParams,
                ),
                Expanded(
                  child: Chat(
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
                ),
              ],
            ),
    );
  }
}
