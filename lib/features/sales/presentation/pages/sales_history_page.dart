import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/customers_controller.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/sales_empty_state.dart';
import '../widgets/sales_scaffold.dart';

/// Status filters, in the order the chip row shows them. The first entry is
/// 'everything'.
const _statuses = <String?>[
  null,
  'PAID',
  'PARTIALLY_PAID',
  'CONFIRMED',
  'RETURNED',
  'VOID',
];

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

    return SalesScaffold(
      title: 'Sales history',
      maxContentWidth: 900,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _searchCtrl,
            label: 'Search',
            prefixIcon: LucideIcons.search,
            hint: 'Invoice number',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 14),
          AppFilterChips(
            height: 36,
            labels: [
              for (final s in _statuses)
                s == null ? 'All' : _titleCase(s.replaceAll('_', ' ')),
            ],
            selected: _statuses.indexOf(_statusFilter),
            onSelected: (i) {
              setState(() => _statusFilter = _statuses[i]);
              _applyFilters();
            },
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildBody(state, customers)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Invoice>> state, List<Customer> customers) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: AppInlineBanner(
          message: "We couldn't load the sales history. Pull the filters again "
              'once the connection is back.',
        ),
      ),
      data: (invoices) {
        final filtered = _filteredInvoices(invoices);
        if (filtered.isEmpty) {
          return SalesEmptyState(
            icon: LucideIcons.receiptText,
            message: _searchCtrl.text.isEmpty && _statusFilter == null
                ? 'No invoices yet — your first sale will show up here.'
                : 'No invoices match those filters.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < filtered.length; i++)
                    _InvoiceRow(
                      invoice: filtered[i],
                      customerName:
                          _customerName(filtered[i].customerId, customers),
                      showDivider: i != filtered.length - 1,
                      onTap: () =>
                          context.push('/sales/invoice/${filtered[i].id}'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _customerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return 'Walk-in';
    return customers.where((c) => c.id == customerId).firstOrNull?.name ?? 'Walk-in';
  }

  static String _titleCase(String value) =>
      value[0] + value.substring(1).toLowerCase();
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.customerName,
    required this.showDivider,
    required this.onTap,
  });

  final Invoice invoice;
  final String customerName;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Semantics(
      button: true,
      label: '${invoice.invoiceNumber}, $customerName',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: lum.hairline))
                : null,
          ),
          child: Row(
            children: [
              ClayContainer(
                variant: ClayVariant.inset,
                color: lum.surface2,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 40,
                height: 40,
                child: Icon(
                  LucideIcons.receiptText,
                  size: 19,
                  color: lum.g500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            invoice.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.monoValue.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: lum.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusPill(invoice.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$customerName · ${_timeAgo(invoice.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: lum.g500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppMoneyText(invoice.grandTotal, size: 15),
                  if (invoice.balance > 0)
                    Text(
                      'Due ${formatPkr(invoice.balance)}',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        color: lum.warningText,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g300),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statusPill(InvoiceStatus status) {
    final (tone, label) = switch (status) {
      InvoiceStatus.paid => (AppPillTone.success, 'Paid'),
      InvoiceStatus.partiallyPaid => (AppPillTone.warning, 'Part. paid'),
      InvoiceStatus.confirmed => (AppPillTone.lumen, 'Credit'),
      InvoiceStatus.returned => (AppPillTone.danger, 'Returned'),
      InvoiceStatus.voided => (AppPillTone.neutral, 'Void'),
      InvoiceStatus.draft => (AppPillTone.neutral, 'Draft'),
    };
    return AppPill(label: label, tone: tone);
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
