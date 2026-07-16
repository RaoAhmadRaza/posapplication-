import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/outbox_entry.dart';
import '../controllers/connectivity_controller.dart';
import '../controllers/sync_controller.dart';

Future<void> showSyncStatusSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const _SyncStatusSheet(),
  );
}

class _SyncStatusSheet extends ConsumerWidget {
  const _SyncStatusSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    final pending =
        ref.watch(outboxCountProvider).maybeWhen(data: (n) => n, orElse: () => 0);
    final lastSync = ref.watch(lastSyncProvider).maybeWhen(data: (v) => v, orElse: () => null);
    final intents = ref.watch(outboxIntentsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sync', style: AppTypography.title2),
                const Spacer(),
                Text(online ? 'Online' : 'Offline',
                    style: AppTypography.footnote.copyWith(
                        color: online ? AppColors.success : AppColors.warning)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Queue: $pending pending · Last sync: ${_fmt(lastSync)}',
              style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Sync now',
                    icon: Icons.sync,
                    onPressed: online
                        ? () => ref.read(drainActionsProvider).drainNow()
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Exceptions',
                    icon: Icons.report_problem_outlined,
                    variant: AppButtonVariant.tinted,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/sync/exceptions');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            Flexible(
              child: intents.when(
                loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator())),
                error: (e, _) => Text('$e', style: AppTypography.footnote),
                data: (rows) => rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.base),
                        child: Text('No queued sales.',
                            style: AppTypography.footnote
                                .copyWith(color: AppColors.textMuted)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _IntentTile(entry: rows[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String? iso) {
    if (iso == null) return 'never';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'never';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _IntentTile extends StatelessWidget {
  const _IntentTile({required this.entry});
  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (entry.status) {
      'DONE' => (AppColors.success, 'DONE'),
      'ABANDONED' => (AppColors.destructive, 'ABANDONED'),
      'FAILED' => (AppColors.warning, 'RETRYING'),
      _ => (AppColors.accent, 'PENDING'),
    };
    final subtitle = entry.status == 'DONE' && entry.invoiceNumber != null
        ? '→ ${entry.invoiceNumber}'
        : entry.lastError ?? entry.localRef;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(entry.localRef, style: AppTypography.subhead),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
      trailing: Text(label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
