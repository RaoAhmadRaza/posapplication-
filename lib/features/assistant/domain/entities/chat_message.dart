/// A single chat turn in the AI companion. Pure domain entity.
enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  /// Null while a message is optimistic/in-flight (not yet persisted).
  final String? id;
  final ChatRole role;
  final String content;
  final DateTime? createdAt;

  ChatMessage copyWith({String? content}) => ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}

/// A saved conversation (thread) between the user and the assistant.
class ChatConversation {
  const ChatConversation({required this.id, this.title, this.updatedAt});

  final String id;
  final String? title;
  final DateTime? updatedAt;
}
