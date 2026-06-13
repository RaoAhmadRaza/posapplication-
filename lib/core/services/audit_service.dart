import 'package:flutter/foundation.dart';
import '../supabase.dart';

class AuditService {
  static const instance = AuditService._();
  const AuditService._();

  void log({
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
  }) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _write(userId, action, entity, entityId, newValues, 2);
  }

  Future<void> _write(
    String userId,
    String action,
    String entity,
    String? entityId,
    Map<String, dynamic>? newValues,
    int retries,
  ) async {
    try {
      await supabase.from('audit_logs').insert({
        'user_id': userId,
        'action': action,
        'entity': entity,
        'entity_id': entityId,
        'new_values': newValues,
      });
    } catch (e) {
      if (retries > 0) {
        _write(userId, action, entity, entityId, newValues, retries - 1);
      } else {
        if (kDebugMode) {
          debugPrint('[AuditService] failed to write audit log: $action $entity — $e');
        }
      }
    }
  }
}
