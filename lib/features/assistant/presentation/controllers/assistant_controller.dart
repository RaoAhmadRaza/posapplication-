import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../domain/entities/assistant_stream_event.dart';
import '../../domain/entities/chat_message.dart';

/// Immutable UI state for the assistant conversation.
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.conversations = const [],
    this.activeConversationId,
    this.sending = false,
    this.toolStatus,
    this.error,
  });

  final List<ChatMessage> messages;

  /// The user's saved threads, newest first — backs the history panel.
  final List<ChatConversation> conversations;

  /// The thread currently shown, or null for an unsaved new chat.
  final String? activeConversationId;

  final bool sending;

  /// Name of the read tool currently running, for a status line ("Looking up…").
  final String? toolStatus;
  final String? error;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    List<ChatConversation>? conversations,
    String? activeConversationId,
    bool clearActiveConversationId = false,
    bool? sending,
    String? toolStatus,
    bool clearToolStatus = false,
    String? error,
    bool clearError = false,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        conversations: conversations ?? this.conversations,
        activeConversationId: clearActiveConversationId
            ? null
            : (activeConversationId ?? this.activeConversationId),
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
  AssistantRepository get _repo => ref.read(assistantRepositoryProvider);

  @override
  AssistantState build() {
    _resumeLast();
    return const AssistantState();
  }

  /// On open: load the thread list and resume the most recent one, so the chat
  /// is still there after navigating away or restarting. Bails if the user has
  /// already started interacting (a race with an eager first message).
  Future<void> _resumeLast() async {
    try {
      final convs = await _repo.listConversations();
      if (state.sending ||
          state.messages.isNotEmpty ||
          state.activeConversationId != null) {
        state = state.copyWith(conversations: convs);
        return;
      }
      if (convs.isEmpty) {
        state = state.copyWith(conversations: convs);
        return;
      }
      final last = convs.first;
      final msgs = await _repo.loadHistory(last.id);
      state = state.copyWith(
        conversations: convs,
        messages: msgs,
        activeConversationId: last.id,
      );
    } on Exception {
      // Leave the state empty — a brand-new chat still works without history.
    }
  }

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
    var createdNew = false;
    try {
      final stream = ref.read(assistantRepositoryProvider).streamReply(
            conversationId: state.activeConversationId,
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
            if (state.activeConversationId == null && conversationId != null) {
              createdNew = true;
              state = state.copyWith(activeConversationId: conversationId);
            }
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

    // A new thread (or a fresh reply that bumped updated_at) changes the list.
    if (createdNew) await _refreshConversations();
  }

  void _writeAssistant(int index, String content) {
    final msgs = [...state.messages];
    if (index >= 0 && index < msgs.length) {
      msgs[index] = msgs[index].copyWith(content: content);
      state = state.copyWith(messages: msgs);
    }
  }

  /// Switch to a saved thread and load its messages.
  Future<void> openConversation(String id) async {
    if (state.sending || id == state.activeConversationId) return;
    try {
      final msgs = await _repo.loadHistory(id);
      state = state.copyWith(
        messages: msgs,
        activeConversationId: id,
        clearError: true,
      );
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Rename a saved thread, then refresh the list so the panel reflects it.
  Future<void> renameConversation(String id, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    await _repo.renameConversation(id, clean);
    await _refreshConversations();
  }

  /// Delete a saved thread; if it was the open one, drop to a new chat.
  Future<void> deleteConversation(String id) async {
    await _repo.deleteConversation(id);
    if (state.activeConversationId == id) {
      state = state.copyWith(
        messages: const [],
        clearActiveConversationId: true,
      );
    }
    await _refreshConversations();
  }

  /// Start a fresh conversation, keeping the saved history list intact.
  void startNewChat() {
    if (state.sending) return;
    state = state.copyWith(
      messages: const [],
      clearActiveConversationId: true,
      clearError: true,
      clearToolStatus: true,
    );
  }

  Future<void> _refreshConversations() async {
    try {
      state = state.copyWith(conversations: await _repo.listConversations());
    } on Exception {
      // Keep the current list on a transient failure.
    }
  }
}
