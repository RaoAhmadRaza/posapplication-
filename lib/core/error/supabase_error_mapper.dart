import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_failure.dart';

/// Maps a raw Supabase/Postgrest exception to a typed [AuthFailure] for
/// background service operations (audit, device, pin, login-throttle). These
/// paths only log the failure, so a coarse mapping is sufficient — the detail
/// is preserved in [UnknownFailure.message] for the debugPrint.
AuthFailure mapSupabaseFailure(Object e) {
  if (e is PostgrestException || e is AuthException) return ServerErrorFailure();
  return UnknownFailure(e.toString());
}
