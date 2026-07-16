import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
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

    final (IconData icon, String label, Color color) = !online
        ? (Icons.cloud_off_rounded, 'Offline', AppColors.warning)
        : pending > 0
            ? (Icons.cloud_upload_rounded, 'Pending($pending)', AppColors.accent)
            : (Icons.cloud_done_rounded, 'Synced', AppColors.success);

    return InkWell(
      onTap: () => showSyncStatusSheet(context),
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
