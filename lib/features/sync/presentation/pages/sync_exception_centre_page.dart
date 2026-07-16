import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/sync_exception.dart';
import '../controllers/sync_controller.dart';

/// OPEN sync_exceptions — terminal replay failures a human works. The resolution
/// is an inventory adjustment / credit override (deep-linked), NOT a JSON merge.
class SyncExceptionCentrePage extends ConsumerWidget {
  const SyncExceptionCentrePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'sync',
      action: 'read',
      fallback: const NoAccessScaffold(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Sync Exceptions', style: AppTypography.headline),
        ),
        body: SafeArea(
          child: ref.watch(syncExceptionsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e', style: AppTypography.footnote)),
                data: (rows) => rows.isEmpty
                    ? Center(
                        child: Text('No open exceptions.',
                            style: AppTypography.subhead
                                .copyWith(color: AppColors.textMuted)),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(syncExceptionsProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.screenPadding),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (_, i) => _ExceptionCard(exception: rows[i]),
                        ),
                      ),
              ),
        ),
      ),
    );
  }
}

class _ExceptionCard extends ConsumerWidget {
  const _ExceptionCard({required this.exception});
  final SyncException exception;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exception.errorCode,
              style: AppTypography.subhead
                  .copyWith(color: AppColors.destructive, fontWeight: FontWeight.w700)),
          if (exception.errorDetail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(exception.errorDetail!,
                style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text('Queued: ${exception.createdAt}',
              style: AppTypography.caption.copyWith(color: AppColors.textHint)),
          if (exception.productIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final pid in exception.productIds)
                  ActionChip(
                    label: const Text('Adjust stock'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    onPressed: () => context.push('/inventory/products/$pid'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          PermissionGate(
            module: 'sync',
            action: 'resolve',
            child: AppButton(
              label: 'Resolve',
              icon: Icons.check,
              onPressed: () => _resolve(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Resolve exception', style: AppTypography.headline),
        content: AppTextField(
          controller: controller,
          label: 'Resolution note',
          prefixIcon: Icons.note_alt_outlined,
          hint: 'e.g. stock adjusted, credited customer',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Resolve')),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    final failure = await ref.read(drainActionsProvider).resolveException(exception.id, note);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failure?.message ?? 'Exception resolved.'),
    ));
  }
}
