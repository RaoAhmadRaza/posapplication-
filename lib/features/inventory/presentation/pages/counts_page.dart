import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_status.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/counts_controller.dart';
import '../controllers/warehouses_controller.dart';
import '../widgets/inventory_ui.dart';

class CountsPage extends ConsumerWidget {
  const CountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preserved: keeps the branch watch that scopes the counts stream, even
    // though the header no longer surfaces the branch name.
    ref.watch(currentBranchProvider);
    final state = ref.watch(countsProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Stock counts',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'update',
          child: AppButton(
            label: 'New count',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => _startNewCount(context, ref),
          ),
        ),
      ],
      child: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          title: "We couldn't load counts",
          body: 'Please try again in a moment.',
          onRetry: () => ref.invalidate(countsProvider),
        ),
        data: (counts) {
          if (counts.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.clipboardCheck,
              title: 'No stock counts yet',
              body: 'Open a count to start auditing inventory.',
              action: PermissionGate(
                module: 'inventory',
                action: 'update',
                child: AppButton(
                  label: 'New count',
                  icon: LucideIcons.plus,
                  onPressed: () => _startNewCount(context, ref),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final c in counts) ...[
                _CountCard(count: c),
                if (c != counts.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  void _startNewCount(BuildContext context, WidgetRef ref) {
    final warehouses = ref.read(warehousesProvider).value ?? <Warehouse>[];
    final active = warehouses.where((w) => w.isActive).toList();

    showAppSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'New stock count',
            subtitle: 'Pick a location to audit.',
          ),
          _WarehouseOption(
            label: 'All locations',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _open(context, ref, warehouseId: null);
            },
          ),
          for (final w in active) ...[
            const SizedBox(height: 8),
            _WarehouseOption(
              label: w.name,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _open(context, ref, warehouseId: w.id);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref, {
    required String? warehouseId,
  }) async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    try {
      final count = await ref.read(countsProvider.notifier).open(
            branchId: branch.id,
            warehouseId: warehouseId,
          );
      if (count != null && context.mounted) {
        context.push('/inventory/counts/${count.id}');
      }
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Failed to open count.');
    }
  }
}

class _WarehouseOption extends StatelessWidget {
  const _WarehouseOption({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.warehouse, size: 18, color: lum.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(color: lum.textPrimary),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
            ],
          ),
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
    final lum = context.lum;
    final (tone, label) = countStatusPill(count.status);

    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];
    final warehouseName = count.warehouseId == null
        ? 'All locations'
        : warehouses
                .where((w) => w.id == count.warehouseId)
                .map((w) => w.name)
                .firstOrNull ??
            'All locations';

    final progress =
        count.totalItems > 0 ? count.itemsCounted / count.totalItems : 0.0;
    final percent =
        count.totalItems > 0 ? (progress * 100).round() : 0;

    return AppCard(
      onTap: () => context.push('/inventory/counts/${count.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 42,
                height: 42,
                child: Center(
                  child: Icon(LucideIcons.clipboardCheck,
                      size: 19, color: lum.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouseName,
                      style: AppTypography.headline
                          .copyWith(color: lum.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ymd(count.createdAt),
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppPill(label: label, tone: tone),
            ],
          ),
          if (count.status != StockCountStatus.completed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: lum.surface2,
                color: progress >= 1 ? lum.success : lum.accent,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${count.itemsCounted}/${count.totalItems} · $percent%',
              style: AppTypography.caption.copyWith(color: lum.g500),
            ),
          ],
          if (count.varianceCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.triangleAlert,
                    size: 14, color: lum.warningText),
                const SizedBox(width: 6),
                Text(
                  '${count.varianceCount} items with variance',
                  style:
                      AppTypography.caption.copyWith(color: lum.warningText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
