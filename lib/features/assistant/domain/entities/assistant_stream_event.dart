/// Events yielded while streaming a reply from the `llm-proxy` edge function.
/// Mirrors the SSE frames the function emits: delta / tool / done / error.
sealed class AssistantStreamEvent {
  const AssistantStreamEvent();
}

/// Incremental assistant text.
final class AssistantDelta extends AssistantStreamEvent {
  const AssistantDelta(this.text);
  final String text;
}

/// A read tool is being invoked server-side (for a lightweight status line).
final class AssistantToolCall extends AssistantStreamEvent {
  const AssistantToolCall(this.name);
  final String name;
}

/// Stream finished; the assistant + user messages are persisted server-side.
final class AssistantDone extends AssistantStreamEvent {
  const AssistantDone(this.conversationId);
  final String? conversationId;
}

/// A failure (pre-stream HTTP error or mid-stream `error` frame).
final class AssistantStreamError extends AssistantStreamEvent {
  const AssistantStreamError(this.message);
  final String message;
}
