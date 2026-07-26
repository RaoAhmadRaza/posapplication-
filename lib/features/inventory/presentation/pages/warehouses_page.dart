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
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/warehouse.dart';
import '../controllers/warehouses_controller.dart';

class WarehousesPage extends ConsumerWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the branch subscription so the list rebuilds on branch change.
    ref.watch(currentBranchProvider);
    final state = ref.watch(warehousesProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Warehouses',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Add warehouse',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/warehouses/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          title: "Unable to load warehouses",
          body: 'Please try again in a moment.',
          onRetry: () => ref.read(warehousesProvider.notifier).refresh(),
        ),
        data: (warehouses) {
          if (warehouses.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.warehouse,
              title: 'No warehouses yet',
              body: 'Create a warehouse to manage inventory per location.',
              action: PermissionGate(
                module: 'inventory',
                action: 'create',
                child: AppButton(
                  label: 'Create warehouse',
                  icon: LucideIcons.plus,
                  onPressed: () =>
                      context.push('/inventory/warehouses/create'),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaLine(warehouses: warehouses),
              const SizedBox(height: 12),
              for (final w in warehouses) ...[
                _WarehouseCard(warehouse: w),
                if (w != warehouses.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.warehouses});
  final List<Warehouse> warehouses;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final defaults = warehouses.where((w) => w.isDefault);
    final text = defaults.isEmpty
        ? '${warehouses.length} locations'
        : '${warehouses.length} locations · current: ${defaults.first.name}';
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        text,
        style: AppTypography.footnote.copyWith(color: lum.g500),
      ),
    );
  }
}

class _WarehouseCard extends ConsumerWidget {
  const _WarehouseCard({required this.warehouse});
  final Warehouse warehouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push('/inventory/warehouses/${warehouse.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 42,
            height: 42,
            child: Center(
              child: Icon(LucideIcons.warehouse, size: 19, color: lum.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  warehouse.code,
                  style: AppTypography.monoValue
                      .copyWith(color: lum.g500, fontSize: 12),
                ),
              ],
            ),
          ),
          if (warehouse.isDefault) ...[
            const SizedBox(width: 10),
            const AppPill(label: 'Default', tone: AppPillTone.lumen),
          ] else ...[
            const SizedBox(width: 10),
            PermissionGate(
              module: 'inventory',
              action: 'update',
              child: AppButton(
                label: 'Set default',
                variant: AppButtonVariant.tinted,
                size: AppButtonSize.sm,
                onPressed: () => ref
                    .read(warehousesProvider.notifier)
                    .setDefault(warehouse.id),
              ),
            ),
          ],
          PermissionGate(
            module: 'inventory',
            action: 'delete',
            child: IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: lum.g500),
              tooltip: 'Delete warehouse',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: 'Delete warehouse',
      message:
          'Delete "${warehouse.name}"? This will fail if the warehouse still has stock.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(warehousesProvider.notifier).remove(warehouse.id);
    if (context.mounted) showAppToast(context, 'Warehouse deleted');
  }
}
