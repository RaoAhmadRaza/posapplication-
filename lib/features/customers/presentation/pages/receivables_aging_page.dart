import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/receivables_aging.dart';
import '../controllers/customers_controller.dart';

class ReceivablesAgingPage extends ConsumerWidget {
  const ReceivablesAgingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agingAsync = ref.watch(receivablesAgingProvider);

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
        title: Text('Receivables Aging', style: AppTypography.headline),
      ),
      body: agingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineBanner(
                    message: 'Could not load receivables aging.',
                    type: BannerType.error),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(receivablesAgingProvider)),
              ],
            ),
          ),
        ),
        data: (aging) => _Body(aging: aging),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.aging});
  final ReceivablesAging aging;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL RECEIVABLE',
                    style: AppTypography.footnote.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Text(formatPkr(aging.totalReceivable),
                    style: AppTypography.largeTitle
                        .copyWith(color: AppColors.destructive)),
                const Divider(
                    color: AppColors.separator, height: AppSpacing.xl),
                _bucket('Current', aging.current),
                _bucket('1–30 days', aging.bucket1To30),
                _bucket('31–60 days', aging.bucket31To60),
                _bucket('61–90 days', aging.bucket61To90),
                _bucket('90+ days', aging.bucket90Plus,
                    color: AppColors.destructive),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('BY CUSTOMER',
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        if (aging.byCustomer.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text('No outstanding receivables.',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textHint)),
            ),
          )
        else
          for (final c in aging.byCustomer) _CustomerRow(customer: c),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _bucket(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textMuted)),
          Text(formatPkr(value),
              style: AppTypography.footnote.copyWith(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer});
  final ReceivablesAgingCustomer customer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/customers/${customer.customerId}'),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.customerName, style: AppTypography.subhead),
                    const SizedBox(height: 2),
                    Text('${customer.daysOverdue} days overdue',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text(formatPkr(customer.balance),
                  style: AppTypography.subhead.copyWith(
                      color: AppColors.destructive,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
