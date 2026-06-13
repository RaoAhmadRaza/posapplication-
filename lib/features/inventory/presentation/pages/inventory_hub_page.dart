import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';

class InventoryHubPage extends ConsumerWidget {
  const InventoryHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Inventory', style: AppTypography.largeTitle),
              const SizedBox(height: AppSpacing.xxl),
              _HubRow(
                icon: Icons.dashboard_rounded,
                title: 'Products',
                subtitle: 'Browse, search, and manage products',
                onTap: () => context.push('/inventory/products'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.category,
                title: 'Categories',
                subtitle: 'Organize products by category',
                onTap: () => context.push('/inventory/categories'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.branding_watermark,
                title: 'Brands',
                subtitle: 'Manage product brands',
                onTap: () => context.push('/inventory/brands'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.qr_code_2,
                title: 'Barcode Templates',
                subtitle: 'Label layouts for printing',
                onTap: () => context.push('/inventory/barcode-templates'),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('Coming Soon'),
              const SizedBox(height: AppSpacing.sm),
              _HubRow(
                icon: Icons.warehouse,
                title: 'Stock',
                subtitle: 'Warehouses, balances, and movements',
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.swap_horiz,
                title: 'Transfers',
                subtitle: 'Move stock between locations',
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Text(label.toUpperCase(), style: AppTypography.footnote.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: enabled ? AppColors.accent : AppColors.textHint, size: 20),
        ),
        title: Text(title, style: AppTypography.headline.copyWith(color: enabled ? AppColors.textPrimary : AppColors.textMuted)),
        subtitle: Text(subtitle, style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
        trailing: enabled ? const Icon(Icons.chevron_right, color: AppColors.separator) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
