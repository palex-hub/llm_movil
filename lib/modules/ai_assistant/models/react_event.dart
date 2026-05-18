sealed class ReActEvent {}

class ThoughtEvent extends ReActEvent {
  final String message;
  ThoughtEvent(this.message);
}

class ToolCallEvent extends ReActEvent {
  final String tool;
  final Map<String, dynamic> args;
  ToolCallEvent(this.tool, this.args);
}

class ObservationEvent extends ReActEvent {
  final String observation;
  ObservationEvent(this.observation);
}

class AnswerTokenEvent extends ReActEvent {
  final String text;
  AnswerTokenEvent(this.text);
}

class ErrorEvent extends ReActEvent {
  final String error;
  ErrorEvent(this.error);
}
