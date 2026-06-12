sealed class ReActEvent {}

class AnswerTokenEvent extends ReActEvent {
  final String text;
  AnswerTokenEvent(this.text);
}

class ErrorEvent extends ReActEvent {
  final String error;
  ErrorEvent(this.error);
}

class ToolRunEvent extends ReActEvent {
  final String toolName;
  final Map<String, dynamic> args;
  ToolRunEvent(this.toolName, this.args);
}

class ToolResultEvent extends ReActEvent {
  final String toolName;
  final String result;
  ToolResultEvent(this.toolName, this.result);
}
