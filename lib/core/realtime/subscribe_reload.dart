import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase.dart';

/// Subscribe to Postgres change events on [table] and invoke [onChange] on every
/// insert/update/delete the caller is allowed to see. RLS scopes the realtime
/// stream server-side — a user never receives another tenant's/user's rows, so
/// no client-side filter is needed; the row-level policy IS the isolation
/// boundary. The channel is removed automatically when the provider disposes.
///
/// Callers pass a plain refetch (`load`); we deliberately reload rather than
/// merge the payload into state — simpler and always correct.
void subscribeReload(Ref ref, String table, void Function() onChange) {
  final channel = supabase
      .channel('rt:$table')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      )
      .subscribe();
  ref.onDispose(() => supabase.removeChannel(channel));
}
