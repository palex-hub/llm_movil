import '../models/react_event.dart';
import 'llm_service.dart';
import 'permission_service.dart';
import 'react_engine.dart';

class ChatEngine {
  final ReactEngine _react;
  final LlmService _llm;
  String _modelPath;

  ChatEngine(this._llm, {String? modelPath})
      : _react = ReactEngine(_llm),
        _modelPath = modelPath ?? PermissionService.modelPath1_5B;

  String get currentModelPath => _modelPath;

  Future<bool> loadModel() async {
    return await _llm.init(_modelPath);
  }

  Future<bool> switchModel(String path) async {
    _modelPath = path;
    final ok = await _llm.switchModel(path);
    if (ok) _react.reset();
    return ok;
  }

  Stream<ReActEvent> sendMessage(String text) {
    return _react.processMessage(text);
  }

  void reset() {
    _react.reset();
  }

  Future<void> dispose() => _llm.dispose();
}
