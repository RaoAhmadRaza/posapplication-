import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _searchCtrl = TextEditingController();
  String? _statusFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(invoicesProvider.notifier).load(
          status: _statusFilter,
        );
  }

  List<Invoice> _filteredInvoices(List<Invoice> invoices) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return invoices;
    return invoices.where((i) => i.invoiceNumber.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'sales',
      action: 'read',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = ref.watch(invoicesProvider);
    final customers = ref.watch(customersProvider).value ?? <Customer>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Sales History', style: AppTypography.headline),
        actions: [
          TextButton(
            onPressed: () => context.push('/sales/pos'),
            child: Text('POS', style: AppTypography.footnote.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, 0),
            child: AppTextField(
              controller: _searchCtrl,
              label: 'Search',
              prefixIcon: Icons.search,
              hint: 'Invoice number',
              onSubmitted: (_) => _applyFilters(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  active: _statusFilter == null,
                  onTap: () {
                    setState(() => _statusFilter = null);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                ...['PAID', 'PARTIALLY_PAID', 'CONFIRMED', 'RETURNED', 'VOID'].map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _FilterChip(
                      label: s.replaceAll('_', ' '),
                      active: _statusFilter == s,
                      onTap: () {
                        setState(() => _statusFilter = _statusFilter == s ? null : s);
                        _applyFilters();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody(state, customers)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Invoice>> state, List<Customer> customers) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: AppInlineBanner(message: 'Could not load sales history.', type: BannerType.error),
        ),
      ),
      data: (invoices) {
        final filtered = _filteredInvoices(invoices);
        if (filtered.isEmpty) {
          return Center(
            child: Text('No sales yet.', style: AppTypography.subhead.copyWith(color: AppColors.textHint)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _InvoiceRow(
            invoice: filtered[i],
            customerName: _customerName(filtered[i].customerId, customers),
            onTap: () => context.push('/sales/invoice/${filtered[i].id}'),
          ),
        );
      },
    );
  }

  String _customerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return 'Walk-in';
    return customers.where((c) => c.id == customerId).firstOrNull?.name ?? 'Walk-in';
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.customerName, required this.onTap});
  final Invoice invoice;
  final String customerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(invoice.invoiceNumber, style: AppTypography.headline),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusChip(status: invoice.status),
                      if (invoice.balance > 0) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text('Due: ${formatPkr(invoice.balance)}',
                            style: AppTypography.caption.copyWith(color: AppColors.warning)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$customerName · ${_timeAgo(invoice.createdAt)}',
                    style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              formatPkr(invoice.grandTotal),
              style: AppTypography.headline.copyWith(color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.separator, size: 20),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      InvoiceStatus.paid => (AppColors.success, 'PAID'),
      InvoiceStatus.partiallyPaid => (AppColors.warning, 'PART. PAID'),
      InvoiceStatus.confirmed => (AppColors.accent, 'CREDIT'),
      InvoiceStatus.returned => (AppColors.destructive, 'RETURNED'),
      InvoiceStatus.voided => (AppColors.textMuted, 'VOID'),
      InvoiceStatus.draft => (AppColors.textHint, 'DRAFT'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.1) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: active ? Border.all(color: AppColors.accent, width: 1) : null,
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
