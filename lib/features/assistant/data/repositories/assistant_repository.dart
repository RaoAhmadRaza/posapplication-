import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/assistant_stream_event.dart';
import '../../domain/entities/chat_message.dart';
import '../datasources/assistant_remote_datasource.dart';
import '../models/chat_message_model.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.read(assistantDataSourceProvider));
});

final assistantDataSourceProvider = Provider<AssistantRemoteDataSource>((ref) {
  return AssistantRemoteDataSource();
});

class AssistantRepository {
  final AssistantRemoteDataSource _ds;

  AssistantRepository(this._ds);

  Future<List<ChatMessage>> loadHistory(String conversationId) async {
    final rows = await _ds.loadHistory(conversationId);
    return rows.map(ChatMessageModel.fromJson).toList();
  }

  Future<List<ChatConversation>> listConversations() async {
    final rows = await _ds.listConversations();
    return rows.map(ChatMessageModel.conversationFromJson).toList();
  }

  Future<void> renameConversation(String id, String title) =>
      _ds.renameConversation(id, title);

  Future<void> deleteConversation(String id) => _ds.deleteConversation(id);

  Stream<AssistantStreamEvent> streamReply({
    String? conversationId,
    required String message,
  }) =>
      _ds.streamReply(conversationId: conversationId, message: message);
}
