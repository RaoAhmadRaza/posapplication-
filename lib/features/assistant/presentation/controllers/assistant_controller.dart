import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../domain/entities/assistant_stream_event.dart';
import '../../domain/entities/chat_message.dart';

/// Immutable UI state for the assistant conversation.
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.sending = false,
    this.toolStatus,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool sending;

  /// Name of the read tool currently running, for a status line ("Looking up…").
  final String? toolStatus;
  final String? error;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? toolStatus,
    bool clearToolStatus = false,
    String? error,
    bool clearError = false,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        toolStatus: clearToolStatus ? null : (toolStatus ?? this.toolStatus),
        error: clearError ? null : (error ?? this.error),
      );
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(
  AssistantController.new,
);

class AssistantController extends Notifier<AssistantState> {
  String? _conversationId;

  @override
  AssistantState build() => const AssistantState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    // Optimistic: append the user's bubble + an empty assistant bubble to stream into.
    final seeded = <ChatMessage>[
      ...state.messages,
      ChatMessage(
        role: ChatRole.user,
        content: trimmed,
        createdAt: DateTime.now(),
      ),
      const ChatMessage(role: ChatRole.assistant, content: ''),
    ];
    final assistantIndex = seeded.length - 1;
    state = state.copyWith(
      messages: seeded,
      sending: true,
      clearError: true,
      clearToolStatus: true,
    );

    final buffer = StringBuffer();
    try {
      final stream = ref.read(assistantRepositoryProvider).streamReply(
            conversationId: _conversationId,
            message: trimmed,
          );

      await for (final event in stream) {
        switch (event) {
          case AssistantDelta(:final text):
            buffer.write(text);
            _writeAssistant(assistantIndex, buffer.toString());
            state = state.copyWith(clearToolStatus: true);
          case AssistantToolCall(:final name):
            state = state.copyWith(toolStatus: name);
          case AssistantDone(:final conversationId):
            _conversationId ??= conversationId;
          case AssistantStreamError(:final message):
            state = state.copyWith(error: message);
        }
      }
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      // If the assistant bubble is still empty (error before any text), surface
      // the error inside it so the turn isn't a blank bubble.
      if (buffer.isEmpty && state.error != null) {
        _writeAssistant(assistantIndex, '⚠️ ${state.error}');
      }
      state = state.copyWith(sending: false, clearToolStatus: true);
    }
  }

  void _writeAssistant(int index, String content) {
    final msgs = [...state.messages];
    if (index >= 0 && index < msgs.length) {
      msgs[index] = msgs[index].copyWith(content: content);
      state = state.copyWith(messages: msgs);
    }
  }

  /// Start a fresh conversation.
  void reset() {
    _conversationId = null;
    state = const AssistantState();
  }
}
