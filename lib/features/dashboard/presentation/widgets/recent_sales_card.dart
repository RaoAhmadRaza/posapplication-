import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_hover.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_section_card.dart';
import 'kpi_descriptors.dart';

/// Most recent invoices, each deep-linking to its invoice page.
class RecentSalesCard extends StatelessWidget {
  const RecentSalesCard({
    super.key,
    required this.sales,
    required this.viewAll,
  });

  final List<RecentSale> sales;

  /// Opens the full sales list — the same drilldown the sales KPI uses.
  final DrilldownNav? viewAll;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return DashboardSectionCard(
      title: 'Recent sales',
      padded: false,
      trailing: viewAll == null
          ? null
          : TextButton(
              onPressed: () =>
                  context.push('/dashboard/drilldown', extra: viewAll),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View all',
                style: AppTypography.footnote.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: lum.accent,
                ),
              ),
            ),
      // Clipped so the last row's hover tint keeps the card's rounded corners.
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final s in sales) _SaleRow(sale: s)],
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale});

  final RecentSale sale;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = switch (sale.status.toUpperCase()) {
      'PAID' => (AppPillTone.success, 'Paid'),
      'PARTIALLY_PAID' => (AppPillTone.warning, 'Part'),
      'CONFIRMED' => (AppPillTone.lumen, 'Credit'),
      'VOID' => (AppPillTone.neutral, 'Void'),
      _ => (AppPillTone.neutral, sale.status),
    };

    return AppHover(
      radius: 0,
      child: InkWell(
        onTap: () => context.push('/sales/invoice/${sale.invoiceNumber}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: lum.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sale.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.monoValue.copyWith(
                        fontSize: 13,
                        color: lum.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sale.customer ?? 'Walk-in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: lum.g600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppPill(label: label, tone: tone),
              const SizedBox(width: 10),
              AppMoneyText(sale.grandTotal, size: 13, decimals: 2),
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight, size: 17, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}
