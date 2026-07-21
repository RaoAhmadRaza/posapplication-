import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_radius.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../controllers/connectivity_controller.dart';
import '../controllers/sync_controller.dart';
import 'sync_status_sheet.dart';

/// POS app-bar chip: Offline · Pending(n) · Synced. Reads the connectivity
/// stream + the local outbox count, DRAINS on reconnect, and opens the status
/// sheet on tap. Offline takes priority over pending.
class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reconnect → drain the outbox oldest-first (the DrainActions guard keeps it serial).
    ref.listen(connectivityProvider, (prev, next) {
      final was = prev?.maybeWhen(data: (v) => v, orElse: () => false) ?? false;
      final now = next.maybeWhen(data: (v) => v, orElse: () => false);
      if (!was && now) ref.read(drainActionsProvider).drainNow();
    });

    final online =
        ref.watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    final pending =
        ref.watch(outboxCountProvider).maybeWhen(data: (n) => n, orElse: () => 0);

    final (String label, AppPillTone tone) = !online
        ? ('Offline', AppPillTone.neutral)
        : pending > 0
            ? ('$pending queued', AppPillTone.warning)
            : ('Synced', AppPillTone.success);

    return Tooltip(
      message: 'Sync status',
      child: Semantics(
        button: true,
        label: 'Sync status: $label',
        child: InkWell(
          onTap: () => showSyncStatusSheet(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AppPill(label: label, tone: tone),
        ),
      ),
    );
  }
}
