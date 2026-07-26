import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_product.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/grn.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/entities/purchase_results.dart';
import '../controllers/purchase_invoices_controller.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../widgets/purchasing_ui.dart';

/// 3-way match: PO ordered/received vs supplier invoice entry.
class PurchaseInvoiceMatchPage extends ConsumerStatefulWidget {
  const PurchaseInvoiceMatchPage({super.key, required this.poId});

  final String poId;

  @override
  ConsumerState<PurchaseInvoiceMatchPage> createState() =>
      _PurchaseInvoiceMatchPageState();
}

class _PurchaseInvoiceMatchPageState
    extends ConsumerState<PurchaseInvoiceMatchPage> {
  final _invoiceNumber = TextEditingController();
  final _amount = TextEditingController();
  final _tax = TextEditingController();
  final _notes = TextEditingController();

  final Map<String, Product> _products = {};
  DateTime? _dueDate;
  String? _grnId;
  bool _seeded = false;
  bool _initializing = false;
  bool _submitting = false;
  String? _error;
  InvoiceCreateResult? _result;

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _amount.dispose();
    _tax.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _ensureInit(
      PurchaseOrder po, List<PurchaseOrderItem> items) async {
    if (_seeded || _initializing) return;
    _initializing = true;
    _amount.text = po.subtotal.toStringAsFixed(2);
    _tax.text = po.taxTotal.toStringAsFixed(2);
    for (final id in items.map((i) => i.productId).toSet()) {
      final (product, _) = await ref.read(getProductUseCaseProvider).call(id);
      if (product != null) _products[id] = product;
    }
    if (!mounted) return;
    setState(() {
      _seeded = true;
      _initializing = false;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Amount must be a positive number.');
      return;
    }
    final tax = double.tryParse(_tax.text.trim());
    if (tax == null || tax < 0) {
      setState(() => _error = 'Tax amount must be zero or greater.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final (result, failure) =
        await ref.read(purchaseInvoicesProvider.notifier).create(
              poId: widget.poId,
              grnId: _grnId,
              supplierInvoiceNumber: _clean(_invoiceNumber),
              amount: amount,
              taxAmount: tax,
              dueDate: _dueDate,
              notes: _clean(_notes),
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _submitting = false;
        _error = failure.message;
      });
      return;
    }
    setState(() {
      _submitting = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseOrderDetailProvider(widget.poId));

    return detail.when(
      loading: () => const AppDetailScaffold(
        eyebrow: 'Purchasing',
        title: 'Match invoice',
        description: '3-way match',
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => AppDetailScaffold(
        eyebrow: 'Purchasing',
        title: 'Match invoice',
        description: '3-way match',
        child: AppErrorState(
          title: 'Unable to load purchase order',
          body: 'Unable to load suggestions. Check your connection and try again.',
          onRetry: () =>
              ref.invalidate(purchaseOrderDetailProvider(widget.poId)),
        ),
      ),
      data: (data) {
        _ensureInit(data.po, data.items);
        final Widget body;
        if (!_seeded) {
          body = const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (_result != null) {
          body = _ResultView(
            result: _result!,
            onDone: () => Navigator.of(context).pop(),
          );
        } else {
          body = _buildForm(context, data.po, data.items);
        }
        return AppDetailScaffold(
          eyebrow: 'Purchasing',
          title: 'Match invoice',
          description: 'PO ${data.po.poNumber} · 3-way match',
          child: body,
        );
      },
    );
  }

  Widget _buildForm(
      BuildContext context, PurchaseOrder po, List<PurchaseOrderItem> items) {
    final grnsAsync = ref.watch(poGrnsProvider(widget.poId));
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final supplierName = suppliers
            .where((s) => s.id == po.supplierId)
            .map((s) => s.name)
            .firstOrNull ??
        'Supplier ${po.supplierId.substring(0, 6)}';

    final left = _PoSummaryColumn(
      po: po,
      items: items,
      products: _products,
      supplierName: supplierName,
    );
    final right = _InvoiceFormColumn(
      invoiceNumber: _invoiceNumber,
      amount: _amount,
      tax: _tax,
      dueDate: _dueDate,
      onPickDueDate: _pickDueDate,
      onClearDueDate: () => setState(() => _dueDate = null),
      grnsAsync: grnsAsync,
      grnId: _grnId,
      onGrnChanged: (v) => setState(() => _grnId = v),
      error: _error,
      submitting: _submitting,
      onSubmit: _create,
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 14), right],
        );
      },
    );
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }
}

class _PoSummaryColumn extends StatelessWidget {
  const _PoSummaryColumn(
      {required this.po,
      required this.items,
      required this.products,
      required this.supplierName});

  final PurchaseOrder po;
  final List<PurchaseOrderItem> items;
  final Map<String, Product> products;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = poStatusPill(po.status);
    return AppSectionCard(
      eyebrow: 'Purchase order',
      trailing: AppPill(label: label, tone: tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv(context, 'PO number', po.poNumber, mono: true),
          _kv(context, 'Supplier', supplierName),
          const SizedBox(height: 14),
          Text(
            'ORDERED VS RECEIVED',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: lum.g500,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in items) _lineRow(context, line),
          Divider(height: 22, color: lum.hairline),
          _money(context, 'Subtotal', po.subtotal),
          _money(context, 'Tax', po.taxTotal),
          _money(context, 'Landed cost', po.landedCost),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('PO total',
                    style: AppTypography.headline
                        .copyWith(color: lum.textPrimary)),
              ),
              AppMoneyText(po.grandTotal, size: 22, color: lum.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(BuildContext context, PurchaseOrderItem line) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              products[line.productId]?.name ?? line.productId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subhead.copyWith(color: lum.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_fmtQty(line.qtyReceived)}/${_fmtQty(line.qtyOrdered)}',
            style: AppTypography.monoValue
                .copyWith(fontSize: 14, color: lum.g600),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool mono = false}) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child:
                Text(k, style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          Text(
            v,
            style: mono
                ? AppTypography.monoValue
                    .copyWith(fontSize: 14, color: lum.textPrimary)
                : AppTypography.subhead.copyWith(color: lum.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _money(BuildContext context, String k, double v) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child:
                Text(k, style: AppTypography.subhead.copyWith(color: lum.g500)),
          ),
          AppMoneyText(v, size: 15, decimals: 2),
        ],
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _InvoiceFormColumn extends StatelessWidget {
  const _InvoiceFormColumn({
    required this.invoiceNumber,
    required this.amount,
    required this.tax,
    required this.dueDate,
    required this.onPickDueDate,
    required this.onClearDueDate,
    required this.grnsAsync,
    required this.grnId,
    required this.onGrnChanged,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController invoiceNumber;
  final TextEditingController amount;
  final TextEditingController tax;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onClearDueDate;
  final AsyncValue<List<Grn>> grnsAsync;
  final String? grnId;
  final ValueChanged<String?> onGrnChanged;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      eyebrow: 'Supplier invoice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            AppInlineBanner(message: error!, type: BannerType.error),
            const SizedBox(height: 14),
          ],
          AppTextField(
            controller: invoiceNumber,
            label: 'Supplier invoice number',
            prefixIcon: LucideIcons.receiptText,
            hint: 'Optional',
          ),
          const SizedBox(height: 14),
          AppMoneyField(controller: amount, label: 'Amount'),
          const SizedBox(height: 14),
          AppMoneyField(controller: tax, label: 'Tax amount'),
          const SizedBox(height: 14),
          _labeled(context, 'Due date', _dueDateWell(context)),
          const SizedBox(height: 14),
          _labeled(context, 'Against GRN', _grnField(context)),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: Listenable.merge([amount, tax]),
            builder: (context, _) {
              final total = (double.tryParse(amount.text.trim()) ?? 0) +
                  (double.tryParse(tax.text.trim()) ?? 0);
              return _invoiceTotalRow(context, total);
            },
          ),
          const SizedBox(height: 18),
          PermissionGate(
            module: 'purchase',
            action: 'create',
            child: AppButton(
              label: 'Create invoice',
              loading: submitting,
              fullWidth: true,
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeled(BuildContext context, String label, Widget child) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label,
              style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        child,
      ],
    );
  }

  Widget _dueDateWell(BuildContext context) {
    final lum = context.lum;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPickDueDate,
      child: ClayContainer(
        variant: ClayVariant.inset,
        color: lum.surface2,
        borderRadius: AppRadius.md,
        isDark: lum.isDark,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 18, color: lum.g500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dueDate != null ? _fmtDate(dueDate!) : 'Set due date (optional)',
                style: AppTypography.fieldText.copyWith(
                  color: dueDate != null ? lum.textPrimary : lum.textTertiary,
                ),
              ),
            ),
            if (dueDate != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClearDueDate,
                child: Icon(LucideIcons.x, size: 16, color: lum.g500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grnField(BuildContext context) {
    return grnsAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => AppInlineBanner(
          message: 'Unable to load GRNs.', type: BannerType.info),
      data: (grns) => AppDropdown<String?>(
        value: grnId,
        placeholder: 'None',
        options: [
          const AppDropdownOption<String?>(value: null, label: 'None'),
          for (final grn in grns)
            AppDropdownOption<String?>(value: grn.id, label: grn.grnNumber),
        ],
        onSelected: onGrnChanged,
      ),
    );
  }

  Widget _invoiceTotalRow(BuildContext context, double total) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Invoice total',
                style: AppTypography.subhead.copyWith(
                    color: lum.textPrimary, fontWeight: FontWeight.w600)),
          ),
          AppMoneyText(total, size: 18, decimals: 2, color: lum.accent),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onDone});

  final InvoiceCreateResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hasVariance = result.matchVariance != 0;
    final tone = hasVariance ? lum.danger : lum.success;
    final toneSoft = hasVariance ? lum.dangerSoft : lum.successSoft;
    final icon = hasVariance ? LucideIcons.alertTriangle : LucideIcons.checkCheck;

    return AppSectionCard(
      eyebrow: 'Match result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ClayContainer(
              variant: ClayVariant.soft,
              color: toneSoft,
              borderRadius: AppRadius.clay,
              isDark: lum.isDark,
              width: 72,
              height: 72,
              child: Icon(icon, size: 30, color: tone),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasVariance ? 'Variance detected' : 'Matched — no variance',
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(color: lum.textPrimary),
          ),
          if (hasVariance) ...[
            const SizedBox(height: 6),
            Center(
              child: AppMoneyText(result.matchVariance,
                  size: 20, decimals: 2, color: lum.danger),
            ),
          ],
          const SizedBox(height: 18),
          Divider(height: 1, color: lum.hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Invoice total',
                    style: AppTypography.subhead.copyWith(color: lum.g500)),
              ),
              AppMoneyText(result.totalAmount, size: 16, decimals: 2),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(label: 'Done', fullWidth: true, onPressed: onDone),
        ],
      ),
    );
  }
}
