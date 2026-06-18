import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_status.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/counts_controller.dart';
import '../controllers/warehouses_controller.dart';

class CountsPage extends ConsumerWidget {
  const CountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(countsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock Counts', style: AppTypography.headline),
            if (branch != null)
              Text(branch.name, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => _showOpenDialog(context, ref),
            ),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AsyncValue<List<StockCount>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(message: 'Could not load counts.', type: BannerType.error),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Retry', onPressed: () => ref.invalidate(countsProvider)),
            ],
          ),
        ),
      ),
      data: (counts) {
        if (counts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.checklist, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text('No stock counts yet', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Open a count to start auditing inventory.', textAlign: TextAlign.center, style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: AppSpacing.xl),
                  PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: AppButton(label: 'New Count', onPressed: () => _showOpenDialog(context, ref)),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          itemCount: counts.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: i < counts.length - 1 ? AppSpacing.md : 0),
            child: _CountCard(count: counts[i]),
          ),
        );
      },
    );
  }

  void _showOpenDialog(BuildContext context, WidgetRef ref) {
    final warehouses = ref.read(warehousesProvider).value ?? <Warehouse>[];
    String? selectedWh;
    final defaultWh = warehouses.where((w) => w.isDefault).firstOrNull;
    selectedWh = defaultWh?.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New Stock Count'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: selectedWh,
                decoration: const InputDecoration(labelText: 'Warehouse (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All locations')),
                  ...warehouses.where((w) => w.isActive).map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                ],
                onChanged: (v) => setLocal(() => selectedWh = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () async {
              Navigator.pop(ctx);
              final branch = ref.read(currentBranchProvider);
              if (branch == null) return;
              try {
                final count = await ref.read(countsProvider.notifier).open(
                  branchId: branch.id,
                  warehouseId: selectedWh,
                );
                if (count != null && context.mounted) {
                  context.push('/inventory/counts/${count.id}');
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to open count.')),
                  );
                }
              }
            }, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends ConsumerWidget {
  const _CountCard({required this.count});
  final StockCount count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = count.totalItems > 0 ? count.itemsCounted / count.totalItems : 0.0;

    return AppCard(
      child: InkWell(
        onTap: () => context.push('/inventory/counts/${count.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Icon(Icons.checklist, color: AppColors.accent, size: 20)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(count.countNumber, style: AppTypography.headline),
                        const SizedBox(height: 2),
                        Text(
                          '${count.itemsCounted}/${count.totalItems} items counted',
                          style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _CountStatusChip(status: count.status),
                ],
              ),
              if (count.status == StockCountStatus.inProgress) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.fieldFill,
                    color: progress >= 1 ? AppColors.success : AppColors.accent,
                    minHeight: 6,
                  ),
                ),
              ],
              if (count.varianceCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${count.varianceCount} variance items',
                      style: AppTypography.caption.copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountStatusChip extends StatelessWidget {
  const _CountStatusChip({required this.status});
  final StockCountStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case StockCountStatus.draft: color = AppColors.textMuted; break;
      case StockCountStatus.inProgress: color = AppColors.accent; break;
      case StockCountStatus.completed: color = AppColors.success; break;
      case StockCountStatus.cancelled: color = AppColors.destructive; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Text(status.dbValue.replaceAll('_', ' '), style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
