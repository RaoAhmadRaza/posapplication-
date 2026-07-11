import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_return.dart';
import '../controllers/purchase_returns_controller.dart';
import 'purchase_orders_page.dart' show fmtPoDate;

const returnStatusLabels = {
  PurchaseReturnStatus.draft: 'Draft',
  PurchaseReturnStatus.confirmed: 'Confirmed',
  PurchaseReturnStatus.cancelled: 'Cancelled',
};

Color returnStatusColor(PurchaseReturnStatus s) => switch (s) {
      PurchaseReturnStatus.draft => AppColors.textMuted,
      PurchaseReturnStatus.confirmed => AppColors.success,
      PurchaseReturnStatus.cancelled => AppColors.destructive,
    };

class PurchaseReturnsPage extends ConsumerWidget {
  const PurchaseReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseReturnsProvider);
    final active = ref.watch(purchaseReturnsProvider.notifier).statusFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Purchase Returns', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusFilterBar(
              active: active,
              onSelected: (s) =>
                  ref.read(purchaseReturnsProvider.notifier).setStatus(s),
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(purchaseReturnsProvider.notifier).refresh(),
                ),
                data: (returns) => returns.isEmpty
                    ? const _EmptyState()
                    : _ReturnsList(returns: returns),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.active, required this.onSelected});
  final PurchaseReturnStatus? active;
  final ValueChanged<PurchaseReturnStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
        children: [
          _chip('All', active == null, () => onSelected(null)),
          for (final s in PurchaseReturnStatus.values) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(returnStatusLabels[s]!, active == s, () => onSelected(s)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ReturnsList extends ConsumerWidget {
  const _ReturnsList({required this.returns});
  final List<PurchaseReturn> returns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    String supplierName(String id) => suppliers
        .where((s) => s.id == id)
        .map((s) => s.name)
        .firstOrNull ??
        'Supplier ${id.substring(0, 6)}';

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      itemCount: returns.length,
      itemBuilder: (_, i) {
        final r = returns[i];
        return Padding(
          padding: EdgeInsets.only(
              bottom: i < returns.length - 1 ? AppSpacing.md : 0),
          child: _ReturnCard(
              ret: r, supplierName: supplierName(r.supplierId)),
        );
      },
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.ret, required this.supplierName});
  final PurchaseReturn ret;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final color = returnStatusColor(ret.status);
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/purchasing/returns/${ret.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ret.returnNumber, style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('$supplierName · ${fmtPoDate(ret.returnDate)}',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatPkr(ret.totalAmount),
                        style: AppTypography.subhead.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(returnStatusLabels[ret.status]!,
                    style: AppTypography.caption
                        .copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_return,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('No purchase returns yet',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text('Open a received purchase order and tap Return to send '
                'goods back to a supplier.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load purchase returns.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
