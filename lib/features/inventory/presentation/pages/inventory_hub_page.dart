import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

class InventoryHubPage extends ConsumerWidget {
  const InventoryHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Inventory', style: AppTypography.largeTitle),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.accent),
                onPressed: () => context.push('/inventory/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _HubRow(
                icon: Icons.dashboard_rounded,
                title: 'Products',
                subtitle: 'Browse, search, and manage products',
                onTap: () => context.push('/inventory/products'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.qr_code_2,
                title: 'Barcode Templates',
                subtitle: 'Label layouts for printing',
                onTap: () => context.push('/inventory/barcode-templates'),
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
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('Stock'),
              const SizedBox(height: AppSpacing.sm),
              _HubRow(
                icon: Icons.warehouse,
                title: 'Warehouses',
                subtitle: 'Manage stock locations per branch',
                onTap: () => context.push('/inventory/warehouses'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.inventory_2,
                title: 'Stock Levels',
                subtitle: 'View balances by product and location',
                onTap: () => context.push('/inventory/stock'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.tune,
                title: 'Adjustments',
                subtitle: 'Damage, theft, write-offs, and recounts',
                onTap: () => context.push('/inventory/adjustments'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.swap_horiz,
                title: 'Transfers',
                subtitle: 'Move stock between branches',
                onTap: () => context.push('/inventory/transfers'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.checklist,
                title: 'Stock Counts',
                subtitle: 'Physical inventory audits',
                onTap: () => context.push('/inventory/counts'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.qr_code,
                title: 'IMEI Lookup',
                subtitle: 'Search and track serialized items',
                onTap: () => context.push('/inventory/imei'),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // NOTE: Suppliers lives here until the Purchasing hub ships (next
              // feature); move this row to that hub when it exists.
              _SectionLabel('Purchasing'),
              const SizedBox(height: AppSpacing.sm),
              _HubRow(
                icon: Icons.local_shipping,
                title: 'Suppliers',
                subtitle: 'Vendor master, balances, and ledger',
                onTap: () => context.push('/suppliers'),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // NOTE: Customers CRM lives here alongside Suppliers until a
              // dedicated CRM hub ships.
              _SectionLabel('Customers'),
              const SizedBox(height: AppSpacing.sm),
              _HubRow(
                icon: Icons.people_outline,
                title: 'Customers',
                subtitle: 'Customer master, credit, and ledger',
                onTap: () => context.push('/customers'),
              ),
              const SizedBox(height: AppSpacing.md),
              _HubRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Receivables Aging',
                subtitle: 'Outstanding balances by age bucket',
                onTap: () => context.push('/receivables'),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // NOTE: Accounting lives here until a dedicated hub tab ships.
              PermissionGate(
                module: 'accounting',
                action: 'read',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Accounting'),
                    const SizedBox(height: AppSpacing.sm),
                    _HubRow(
                      icon: Icons.account_balance_outlined,
                      title: 'Accounting',
                      subtitle: 'Ledger, journals, vouchers, expenses, reports',
                      onTap: () => context.push('/accounting'),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
              // NOTE: Repair lives here until a dedicated hub tab ships.
              PermissionGate(
                module: 'repair',
                action: 'read',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Repair & Service'),
                    const SizedBox(height: AppSpacing.sm),
                    _HubRow(
                      icon: Icons.build_outlined,
                      title: 'Repairs',
                      subtitle: 'Intake, kanban board, close & invoice',
                      onTap: () => context.push('/repair'),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
              // NOTE: HR lives here until a dedicated hub tab ships.
              PermissionGate(
                module: 'hr',
                action: 'read',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('HR & Payroll'),
                    const SizedBox(height: AppSpacing.sm),
                    _HubRow(
                      icon: Icons.groups_outlined,
                      title: 'Employees',
                      subtitle: 'Employees, shifts, payroll',
                      onTap: () => context.push('/hr'),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
              _SectionLabel('Data'),
              const SizedBox(height: AppSpacing.sm),
              PermissionGate(
                module: 'inventory',
                action: 'create',
                child: _HubRow(
                  icon: Icons.file_upload_outlined,
                  title: 'Import Data',
                  subtitle: 'Load data from a previous system',
                  onTap: () => context.push('/inventory/import-migration'),
                ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        title: Text(title, style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.separator),
        onTap: onTap,
      ),
    );
  }
}
