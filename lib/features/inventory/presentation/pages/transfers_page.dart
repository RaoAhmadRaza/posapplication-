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
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/stock_transfer_status.dart';
import '../controllers/transfers_controller.dart';

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  String _direction = 'all';

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(transfersProvider);

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
            Text('Transfers', style: AppTypography.headline),
            if (branch != null)
              Text(branch.name, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/transfers/create'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DirectionChip(label: 'All', value: 'all', selected: _direction, onTap: (v) => setState(() => _direction = v)),
                      const SizedBox(width: AppSpacing.sm),
                      _DirectionChip(label: 'Outgoing', value: 'outgoing', selected: _direction, onTap: (v) => setState(() => _direction = v)),
                      const SizedBox(width: AppSpacing.sm),
                      _DirectionChip(label: 'Incoming', value: 'incoming', selected: _direction, onTap: (v) => setState(() => _direction = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<StockTransfer>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(message: 'Could not load transfers.', type: BannerType.error),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Retry', onPressed: () => ref.invalidate(transfersProvider)),
            ],
          ),
        ),
      ),
      data: (transfers) {
        final branch = ref.read(currentBranchProvider);
        var filtered = transfers;
        if (_direction == 'outgoing') {
          filtered = transfers.where((t) => t.fromBranchId == branch?.id).toList();
        } else if (_direction == 'incoming') {
          filtered = transfers.where((t) => t.toBranchId == branch?.id).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _direction != 'all' ? 'No $_direction transfers' : 'No transfers yet',
                    style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Create a stock transfer to move inventory between branches.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: i < filtered.length - 1 ? AppSpacing.md : 0),
            child: _TransferCard(transfer: filtered[i]),
          ),
        );
      },
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label, value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.1) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: active ? Border.all(color: AppColors.accent, width: 1) : null,
        ),
        child: Center(
          child: Text(label, style: AppTypography.footnote.copyWith(
            color: active ? AppColors.accent : AppColors.textMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ),
      ),
    );
  }
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.transfer});
  final StockTransfer transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.read(currentBranchProvider);
    final isSource = transfer.fromBranchId == branch?.id;
    final isDest = transfer.toBranchId == branch?.id;

    return AppCard(
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
                  child: const Center(
                    child: Icon(Icons.swap_horiz, color: AppColors.accent, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transfer.transferNumber, style: AppTypography.headline),
                      const SizedBox(height: 2),
                      Text(
                        'From Branch ${transfer.fromBranchId.substring(0, 8)}... → To Branch ${transfer.toBranchId.substring(0, 8)}...',
                        style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: transfer.status),
              ],
            ),
            if (isSource && transfer.status == StockTransferStatus.draft || isDest && transfer.status == StockTransferStatus.inTransit || isSource && transfer.status == StockTransferStatus.inTransit) ...[
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isSource && transfer.status == StockTransferStatus.draft) ...[
                    PermissionGate(
                      module: 'inventory',
                      action: 'update',
                      child: AppButton(
                        label: 'Dispatch',
                        variant: AppButtonVariant.tinted,
                        onPressed: () {
                          ref.read(transfersProvider.notifier).dispatch(transfer.id);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PermissionGate(
                      module: 'inventory',
                      action: 'update',
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.destructive,
                        onPressed: () => _confirmCancel(context, ref, transfer.id),
                      ),
                    ),
                  ],
                  if (isDest && (transfer.status == StockTransferStatus.inTransit || transfer.status == StockTransferStatus.partiallyReceived)) ...[
                    PermissionGate(
                      module: 'inventory',
                      action: 'update',
                      child: AppButton(
                        label: 'Receive',
                        variant: AppButtonVariant.tinted,
                        onPressed: () => context.push('/inventory/transfers/${transfer.id}/receive'),
                      ),
                    ),
                  ],
                  if (isSource && transfer.status == StockTransferStatus.inTransit) ...[
                    const SizedBox(width: AppSpacing.sm),
                    PermissionGate(
                      module: 'inventory',
                      action: 'update',
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.destructive,
                        onPressed: () => _confirmCancel(context, ref, transfer.id),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transfer'),
        content: const Text('Cancel this transfer? Dispatched stock will be returned to source.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); ref.read(transfersProvider.notifier).cancel(id); },
            child: Text('Cancel Transfer', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final StockTransferStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case StockTransferStatus.draft: color = AppColors.textMuted; break;
      case StockTransferStatus.inTransit: color = AppColors.accent; break;
      case StockTransferStatus.partiallyReceived: color = AppColors.warning; break;
      case StockTransferStatus.received: color = AppColors.success; break;
      case StockTransferStatus.cancelled: color = AppColors.destructive; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        status.dbValue.replaceAll('_', ' '),
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
