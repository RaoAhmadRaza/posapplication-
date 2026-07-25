import '../../domain/entities/chat_message.dart';

/// Maps chat_messages / chat_conversations rows → domain entities.
class ChatMessageModel {
  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        role: (json['role'] as String?) == 'assistant'
            ? ChatRole.assistant
            : ChatRole.user,
        content: (json['content'] as String?) ?? '',
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  static ChatConversation conversationFromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'] as String,
        title: json['title'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String),
      );
}
