import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/communication_log.dart';
import '../../domain/entities/message_template.dart';

final messageTemplatesProvider = AsyncNotifierProvider<MessageTemplatesController,
    List<MessageTemplate>>(MessageTemplatesController.new);

class MessageTemplatesController extends AsyncNotifier<List<MessageTemplate>> {
  @override
  Future<List<MessageTemplate>> build() {
    return ref.read(notificationRepositoryProvider).loadTemplates();
  }

  Future<void> upsert(MessageTemplate template) async {
    await ref.read(notificationRepositoryProvider).upsertTemplate(template);
    ref.invalidateSelf();
    await future;
  }
}

final communicationLogProvider = AsyncNotifierProvider<CommunicationLogController,
    List<CommunicationLogEntry>>(CommunicationLogController.new);

class CommunicationLogController
    extends AsyncNotifier<List<CommunicationLogEntry>> {
  @override
  Future<List<CommunicationLogEntry>> build() {
    return ref.read(notificationRepositoryProvider).loadCommunicationLog();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).loadCommunicationLog(),
    );
  }
}

/// One-shot bulk-send actions; returns the recipient count.
final bulkCommunicationControllerProvider =
    Provider<BulkCommunicationController>((ref) {
  return BulkCommunicationController(ref.read(notificationRepositoryProvider));
});

class BulkCommunicationController {
  BulkCommunicationController(this._repo);
  final NotificationRepository _repo;

  Future<int> preview(String segment, String? tag, String channel) =>
      _repo.previewBulk(segment, tag, channel);

  Future<int> enqueue(
    String segment,
    String? tag,
    String templateCode,
    String channel,
  ) =>
      _repo.enqueueBulk(segment, tag, templateCode, channel);
}
