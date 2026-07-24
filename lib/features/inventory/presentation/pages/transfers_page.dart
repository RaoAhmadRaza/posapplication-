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
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/stock_transfer_status.dart';
import '../controllers/transfers_controller.dart';
import '../widgets/inventory_ui.dart';

const _kDirections = ['all', 'outgoing', 'incoming'];

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transfersProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Transfers',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'New transfer',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/transfers/create'),
          ),
        ),
      ],
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppFilterChips(
              labels: const ['All', 'Outgoing', 'Incoming'],
              selected: _selected,
              onSelected: (i) => setState(() => _selected = i),
            ),
          ),
          const SizedBox(height: 16),
          _body(state),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<List<StockTransfer>> state) {
    return state.when(
      loading: () => const AppListSkeleton(),
      error: (e, _) => AppErrorState(
        title: "We couldn't load transfers",
        body: 'Please try again in a moment.',
        onRetry: () => ref.invalidate(transfersProvider),
      ),
      data: (transfers) {
        final branch = ref.read(currentBranchProvider);
        final direction = _kDirections[_selected];
        var filtered = transfers;
        if (direction == 'outgoing') {
          filtered =
              transfers.where((t) => t.fromBranchId == branch?.id).toList();
        } else if (direction == 'incoming') {
          filtered =
              transfers.where((t) => t.toBranchId == branch?.id).toList();
        }

        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: LucideIcons.arrowLeftRight,
            title: direction != 'all'
                ? 'No $direction transfers'
                : 'No transfers yet',
            body: 'Create a stock transfer to move inventory between branches.',
            action: PermissionGate(
              module: 'inventory',
              action: 'create',
              child: AppButton(
                label: 'New transfer',
                icon: LucideIcons.plus,
                onPressed: () => context.push('/inventory/transfers/create'),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final t in filtered) ...[
              _TransferCard(transfer: t),
              if (t != filtered.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.transfer});
  final StockTransfer transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final branch = ref.read(currentBranchProvider);
    final isIncoming = transfer.toBranchId == branch?.id;
    final status = transfer.status;
    final (tone, label) = transferStatusPill(status);

    final showDispatch = status == StockTransferStatus.draft;
    final showReceive =
        status == StockTransferStatus.inTransit && isIncoming;
    final showCancel = status != StockTransferStatus.received &&
        status != StockTransferStatus.cancelled;
    final hasActions = showDispatch || showReceive || showCancel;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.transitSoft,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 42,
                height: 42,
                child: Center(
                  child: Icon(LucideIcons.arrowLeftRight,
                      size: 19, color: lum.transit),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From Branch ${transfer.fromBranchId.substring(0, 8)}... → To Branch ${transfer.toBranchId.substring(0, 8)}...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline
                          .copyWith(color: lum.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ymd(transfer.createdAt),
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppPill(label: label, tone: tone),
            ],
          ),
          if (hasActions) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showDispatch)
                  PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: AppButton(
                      label: 'Dispatch',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      onPressed: () => ref
                          .read(transfersProvider.notifier)
                          .dispatch(transfer.id),
                    ),
                  ),
                if (showReceive)
                  PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: AppButton(
                      label: 'Receive',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      onPressed: () => context.push(
                          '/inventory/transfers/${transfer.id}/receive'),
                    ),
                  ),
                if (showCancel)
                  PermissionGate(
                    module: 'inventory',
                    action: 'update',
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.sm,
                      onPressed: () => _confirmCancel(context, ref),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: 'Cancel transfer',
      message:
          'Cancel this transfer? Dispatched stock will be returned to source.',
      confirmLabel: 'Cancel transfer',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(transfersProvider.notifier).cancel(transfer.id);
    if (context.mounted) showAppToast(context, 'Transfer cancelled');
  }
}
