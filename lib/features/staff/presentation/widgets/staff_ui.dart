import '../../../../core/design/widgets/app_pill.dart';

/// Status label + pill tone for a staff invite, shared by the list card so the
/// mapping lives in one place. Mirrors the design export's chip colours.
(String, AppPillTone) inviteStatusUi(String status) => switch (status) {
      'PENDING' => ('Pending', AppPillTone.lumen),
      'AWAITING_CONFIRMATION' => ('Awaiting confirmation', AppPillTone.warning),
      'REDEEMED' => ('Redeemed', AppPillTone.success),
      'EXPIRED' => ('Expired', AppPillTone.neutral),
      'REVOKED' => ('Revoked', AppPillTone.danger),
      _ => (status, AppPillTone.neutral),
    };

/// Avatar initials — first letter of each of the first two words of the name,
/// falling back to the email. Returns '?' when neither is present.
String staffInitials(String? name, String? email) {
  final source = (name != null && name.trim().isNotEmpty) ? name.trim() : (email ?? '');
  final words = source.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return words.take(2).map((w) => w[0]).join().toUpperCase();
}

/// Compact "sent" label for an invite row — the design shows relative time.
String relativeSince(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}
