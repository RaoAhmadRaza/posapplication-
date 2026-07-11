import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';

class PurchaseHubPage extends StatelessWidget {
  const PurchaseHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Purchasing', style: AppTypography.largeTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _HubRow(
                icon: Icons.receipt_long,
                title: 'Purchase Orders',
                subtitle: 'Create, submit, and track POs',
                onTap: () => context.push('/purchasing/orders'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.local_shipping,
                title: 'Suppliers',
                subtitle: 'Vendor master, balances, and ledger',
                onTap: () => context.push('/suppliers'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.request_quote,
                title: 'Purchase Invoices',
                subtitle: 'Bills, balances, and matching',
                onTap: () => context.push('/purchasing/invoices'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.payments,
                title: 'Supplier Payments',
                subtitle: 'Record payments against invoices',
                onTap: () => context.push('/purchasing/payments/create'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.auto_awesome,
                title: 'Reorder Suggestions',
                subtitle: 'Items at or below reorder point',
                onTap: () => context.push('/purchasing/reorder'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.assignment_return,
                title: 'Purchase Returns',
                subtitle: 'Return received goods to suppliers',
                onTap: () => context.push('/purchasing/returns'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        title: Text(title,
            style: AppTypography.headline
                .copyWith(color: AppColors.textPrimary)),
        subtitle: Text(subtitle,
            style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.separator),
        onTap: onTap,
      ),
    );
  }
}
