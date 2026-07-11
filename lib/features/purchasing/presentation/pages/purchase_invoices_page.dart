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
import '../../domain/entities/purchase_invoice.dart';
import '../controllers/purchase_invoices_controller.dart';

const _statusLabels = {
  PurchaseInvoiceStatus.draft: 'Draft',
  PurchaseInvoiceStatus.pending: 'Pending',
  PurchaseInvoiceStatus.approved: 'Approved',
  PurchaseInvoiceStatus.paid: 'Paid',
  PurchaseInvoiceStatus.void_: 'Void',
};

Color _statusColor(PurchaseInvoiceStatus s) => switch (s) {
      PurchaseInvoiceStatus.draft => AppColors.textMuted,
      PurchaseInvoiceStatus.pending => AppColors.accent,
      PurchaseInvoiceStatus.approved => AppColors.success,
      PurchaseInvoiceStatus.paid => AppColors.success,
      PurchaseInvoiceStatus.void_ => AppColors.destructive,
    };

class PurchaseInvoicesPage extends ConsumerWidget {
  const PurchaseInvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseInvoicesProvider);
    final activeStatus = ref.watch(purchaseInvoicesProvider.notifier).statusFilter;

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
        title: Text('Purchase Invoices', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusFilterBar(
              active: activeStatus,
              onSelected: (s) =>
                  ref.read(purchaseInvoicesProvider.notifier).setStatus(s),
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(purchaseInvoicesProvider.notifier).refresh(),
                ),
                data: (invoices) => invoices.isEmpty
                    ? const _EmptyState()
                    : _InvoicesList(invoices: invoices),
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
  final PurchaseInvoiceStatus? active;
  final ValueChanged<PurchaseInvoiceStatus?> onSelected;

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
          for (final s in PurchaseInvoiceStatus.values) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(_statusLabels[s]!, active == s, () => onSelected(s)),
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

class _InvoicesList extends StatelessWidget {
  const _InvoicesList({required this.invoices});
  final List<PurchaseInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      itemCount: invoices.length,
      itemBuilder: (_, i) {
        final inv = invoices[i];
        return Padding(
          padding: EdgeInsets.only(
              bottom: i < invoices.length - 1 ? AppSpacing.md : 0),
          child: _InvoiceCard(invoice: inv),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final title = invoice.supplierInvoiceNumber ??
        'PO ${invoice.poId.substring(0, invoice.poId.length.clamp(0, 8))}';
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/purchasing/invoices/${invoice.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTypography.headline),
                  ),
                  _StatusBadge(status: invoice.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: AppTypography.footnote),
                  Text(formatPkr(invoice.totalAmount),
                      style: AppTypography.subhead),
                ],
              ),
              if (invoice.balance > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Balance', style: AppTypography.footnote),
                    Text(formatPkr(invoice.balance),
                        style: AppTypography.subhead.copyWith(
                            color: AppColors.destructive,
                            fontWeight: FontWeight.w600)),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PurchaseInvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        _statusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
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
            const Icon(Icons.receipt_long, size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('No purchase invoices',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text('Invoices appear here once created from a received order.',
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
                message: 'Could not load invoices.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
