import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../domain/entities/receivables_aging.dart';
import '../controllers/customers_controller.dart';

/// The five aging buckets, in order, with the tone the design assigns each.
enum _Bucket {
  current('Current', AppPillTone.success),
  d1to30('1–30 days', AppPillTone.lumen),
  d31to60('31–60 days', AppPillTone.warning),
  d61to90('61–90 days', AppPillTone.neutral),
  d90plus('90+ days', AppPillTone.danger);

  const _Bucket(this.label, this.tone);
  final String label;
  final AppPillTone tone;
}

_Bucket _bucketFor(int daysOverdue) {
  if (daysOverdue <= 0) return _Bucket.current;
  if (daysOverdue <= 30) return _Bucket.d1to30;
  if (daysOverdue <= 60) return _Bucket.d31to60;
  if (daysOverdue <= 90) return _Bucket.d61to90;
  return _Bucket.d90plus;
}

/// Accent colour for a bucket's tone — the tile's top rule and nothing more.
Color _toneColor(LumColors lum, AppPillTone tone) => switch (tone) {
      AppPillTone.success => lum.successText,
      AppPillTone.lumen => lum.accent,
      AppPillTone.warning => lum.warningText,
      AppPillTone.danger => lum.dangerText,
      _ => lum.g400,
    };

class ReceivablesAgingPage extends ConsumerWidget {
  const ReceivablesAgingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agingAsync = ref.watch(receivablesAgingProvider);

    return ModuleScaffold(
      title: 'Receivables',
      maxContentWidth: 900,
      child: agingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          icon: LucideIcons.cloudOff,
          title: "Unable to load receivables",
          body: 'Unable to reach the server. Try again in a moment.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(receivablesAgingProvider),
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
    final isWide = ModuleScaffold.isWideOf(context);

    // Per-bucket customer counts, derived from the breakdown already in the
    // payload — no separate query, no invented figure.
    final counts = <_Bucket, int>{for (final b in _Bucket.values) b: 0};
    for (final c in aging.byCustomer) {
      counts[_bucketFor(c.daysOverdue)] =
          (counts[_bucketFor(c.daysOverdue)] ?? 0) + 1;
    }

    final amounts = <_Bucket, double>{
      _Bucket.current: aging.current,
      _Bucket.d1to30: aging.bucket1To30,
      _Bucket.d31to60: aging.bucket31To60,
      _Bucket.d61to90: aging.bucket61To90,
      _Bucket.d90plus: aging.bucket90Plus,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16, 12, isWide ? 32 : 16, isWide ? 32 : 24),
      children: [
        _TotalsCard(
          total: aging.totalReceivable,
          amounts: amounts,
          counts: counts,
          isWide: isWide,
        ),
        const SizedBox(height: 16),
        _ByCustomerCard(rows: aging.byCustomer),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.total,
    required this.amounts,
    required this.counts,
    required this.isWide,
  });

  final double total;
  final Map<_Bucket, double> amounts;
  final Map<_Bucket, int> counts;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Total outstanding',
                  style: AppTypography.title2
                      .copyWith(fontSize: 16, color: lum.textPrimary),
                ),
              ),
              AppMoneyText(total,
                  size: 26, decimals: 2, color: lum.textPrimary),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              // Five across when wide enough, else a fluid 2-up — item width
              // derived from the measured row, not a fixed guess.
              final cols = constraints.maxWidth >= 640 ? 5 : 2;
              final itemWidth =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final b in _Bucket.values)
                    SizedBox(
                      width: itemWidth,
                      child: _BucketTile(
                        bucket: b,
                        amount: amounts[b] ?? 0,
                        count: counts[b] ?? 0,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.bucket,
    required this.amount,
    required this.count,
  });

  final _Bucket bucket;
  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          top: BorderSide(color: _toneColor(lum, bucket.tone), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bucket.label,
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: lum.g600,
            ),
          ),
          const SizedBox(height: 8),
          AppMoneyText(amount, size: 16, decimals: 2, color: lum.textPrimary),
          const SizedBox(height: 4),
          Text(
            '$count customers',
            style: AppTypography.caption.copyWith(fontSize: 11.5, color: lum.g400),
          ),
        ],
      ),
    );
  }
}

class _ByCustomerCard extends StatelessWidget {
  const _ByCustomerCard({required this.rows});
  final List<ReceivablesAgingCustomer> rows;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'BY CUSTOMER',
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: lum.g500,
            ),
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No outstanding receivables.',
                    style: AppTypography.body.copyWith(color: lum.g500)),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _CustomerRow(
                customer: rows[i],
                showDivider: i < rows.length - 1,
              ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.showDivider});
  final ReceivablesAgingCustomer customer;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final bucket = _bucketFor(customer.daysOverdue);

    return Semantics(
      button: true,
      label: customer.customerName,
      child: InkWell(
        onTap: () => context.push('/customers/${customer.customerId}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: lum.hairline))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline
                          .copyWith(fontSize: 15, color: lum.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    AppPill(label: bucket.label, tone: bucket.tone),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppMoneyText(customer.balance,
                  size: 15, decimals: 2, color: lum.textPrimary),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}
