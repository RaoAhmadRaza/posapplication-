import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/env.dart';
import '../../../../core/supabase.dart';
import '../../domain/entities/assistant_stream_event.dart';

/// All Supabase + edge-function calls for the AI companion.
///
/// History/conversation reads go through the RLS-scoped client (a user sees only
/// their own rows). The reply stream cannot use `functions.invoke` (it buffers the
/// whole response), so it POSTs directly to the function URL and parses the SSE
/// stream — the caller's JWT is attached so the edge function auth-gates + scopes it.
class AssistantRemoteDataSource {
  final SupabaseClient _client = supabase;

  Future<List<Map<String, dynamic>>> loadHistory(String conversationId) async {
    final rows = await _client
        .from('chat_messages')
        .select('id, role, content, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final rows = await _client
        .from('chat_conversations')
        .select('id, title, updated_at')
        .order('updated_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Streams the assistant's reply. Yields delta/tool/done/error events.
  Stream<AssistantStreamEvent> streamReply({
    String? conversationId,
    required String message,
  }) async* {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      _log('no session — not signed in');
      yield const AssistantStreamError('You are not signed in.');
      return;
    }

    final url = '${Env.supabaseUrl}/functions/v1/llm-proxy';
    _log('POST $url  hasToken=true tokenLen=${token.length} '
        'anonKeyLen=${Env.supabaseAnonKey.length} '
        'conv=${conversationId ?? "new"} msgLen=${message.length}');

    final request = http.Request(
      'POST',
      Uri.parse(url),
    )
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'conversation_id': ?conversationId,
        'message': message,
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      _log('status ${response.statusCode}');

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        _log('non-200 body: $body');
        yield AssistantStreamError(_httpError(body, response.statusCode));
        return;
      }

      var eventName = 'message';
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty) {
          eventName = 'message';
          continue;
        }
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          final decoded =
              jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
          final event = _toEvent(eventName, decoded);
          if (event == null) continue;
          if (event is! AssistantDelta) _log('event: $eventName $decoded');
          yield event;
        }
      }
      _log('stream closed');
    } on http.ClientException catch (e) {
      _log('client exception: ${e.message}');
      yield AssistantStreamError(e.message);
    } finally {
      client.close();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[assistant] $message');
  }

  AssistantStreamEvent? _toEvent(String name, Map<String, dynamic> data) {
    switch (name) {
      case 'delta':
        return AssistantDelta(data['text'] as String? ?? '');
      case 'tool':
        return AssistantToolCall(data['name'] as String? ?? '');
      case 'done':
        return AssistantDone(data['conversation_id'] as String?);
      case 'error':
        return AssistantStreamError(
            data['message'] as String? ?? 'Something went wrong.');
      default:
        return null;
    }
  }

  String _httpError(String body, int status) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = (json['error'] ?? json['message'] ?? json['msg']) as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } on FormatException {
      // not JSON — fall through and surface the raw body below
    }
    final snippet = body.trim();
    if (snippet.isEmpty) return 'Request failed ($status).';
    return 'Request failed ($status): '
        '${snippet.length > 200 ? snippet.substring(0, 200) : snippet}';
  }
}
