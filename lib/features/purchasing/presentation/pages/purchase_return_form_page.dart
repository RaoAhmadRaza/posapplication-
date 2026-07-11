import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_product.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/failures/purchase_failure.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_returns_controller.dart';

/// Return received goods to a supplier — reverses stock (RETURN_OUT), retires
/// serialized IMEIs, and credits the supplier ledger. Entered from a PO or bill.
class PurchaseReturnFormPage extends ConsumerStatefulWidget {
  const PurchaseReturnFormPage({
    super.key,
    required this.poId,
    this.grnId,
    this.invoiceId,
  });

  final String poId;
  final String? grnId;
  final String? invoiceId;

  @override
  ConsumerState<PurchaseReturnFormPage> createState() =>
      _PurchaseReturnFormPageState();
}

class _PurchaseReturnFormPageState
    extends ConsumerState<PurchaseReturnFormPage> {
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, TextEditingController> _qtyReturned = {};
  final Map<String, TextEditingController> _imeiInput = {};
  final Map<String, List<String>> _imeis = {};
  final Map<String, Product> _products = {};

  bool _init = false;
  bool _initializing = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    for (final m in [_qtyReturned, _imeiInput]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _ensureInit(List<PurchaseOrderItem> lines) async {
    if (_init || _initializing) return;
    _initializing = true;
    for (final line in lines) {
      _qtyReturned[line.id] = TextEditingController(text: '0');
      _imeiInput[line.id] = TextEditingController();
      _imeis[line.id] = [];
    }
    for (final id in lines.map((l) => l.productId).toSet()) {
      final (product, _) = await ref.read(getProductUseCaseProvider).call(id);
      if (product != null) _products[id] = product;
    }
    if (!mounted) return;
    setState(() {
      _init = true;
      _initializing = false;
    });
  }

  bool _isSerialized(PurchaseOrderItem line) =>
      _products[line.productId]?.type == ProductType.serialized;

  double _qty(String lineId) =>
      double.tryParse(_qtyReturned[lineId]!.text.trim()) ?? 0;

  double _liveTotal(List<PurchaseOrderItem> lines) {
    var total = 0.0;
    for (final line in lines) {
      final qty = _qty(line.id);
      if (qty <= 0) continue;
      final lineTotal = qty * line.unitCost;
      total += lineTotal + lineTotal * line.taxPct / 100.0;
    }
    return total;
  }

  Future<void> _scanImei(String lineId) async {
    final code = await scanBarcode(context, title: 'Scan IMEI');
    if (!mounted) return;
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _addImei(lineId, code);
  }

  void _addImei(String lineId, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final list = _imeis[lineId]!;
    if (list.contains(value)) return;
    setState(() {
      list.add(value);
      _imeiInput[lineId]!.clear();
    });
  }

  void _removeImei(String lineId, String value) {
    setState(() => _imeis[lineId]!.remove(value));
  }

  Future<void> _submit(
      PurchaseOrder po, List<PurchaseOrderItem> lines, Map<String, double> available) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason for the return.');
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final line in lines) {
      final qty = _qty(line.id);
      if (qty <= 0) continue; // skip lines left at 0
      final avail = available[line.id] ?? 0;
      if (qty > avail) {
        setState(() => _error =
            'Return qty exceeds available (${_fmtQty(avail)}) for a line.');
        return;
      }
      final imeis = _imeis[line.id]!;
      if (_isSerialized(line) && imeis.length != qty) {
        setState(() => _error =
            'Serialized line needs exactly ${qty.toInt()} IMEIs — ${imeis.length} captured.');
        return;
      }
      final map = <String, dynamic>{
        'po_item_id': line.id,
        'qty_returned': qty,
      };
      if (_isSerialized(line)) map['imei_ids'] = List<String>.from(imeis);
      items.add(map);
    }

    if (items.isEmpty) {
      setState(() => _error = 'Enter a return quantity for at least one line.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final (result, failure) =
        await ref.read(purchaseReturnsProvider.notifier).create(
              branchId: po.branchId,
              poId: widget.poId,
              grnId: widget.grnId,
              invoiceId: widget.invoiceId,
              reason: reason,
              notes: _clean(_notes),
              items: items,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _submitting = false);
      if (failure is PurchaseReturnExceedsReceivedFailure ||
          failure is PurchaseImeiCountMismatchFailure ||
          failure is PurchaseImeiNotFoundFailure) {
        setState(() => _error = failure.message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }

    // Refresh everything the return touched so balances/stock reflect it.
    ref.invalidate(purchaseOrderDetailProvider(widget.poId));
    ref.invalidate(poReturnedQtysProvider(widget.poId));
    ref.invalidate(supplierLedgerProvider(po.supplierId));
    ref.invalidate(payablesAgingProvider);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return ${result!.returnNumber} recorded.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseOrderDetailProvider(widget.poId));
    final returnedAsync = ref.watch(poReturnedQtysProvider(widget.poId));

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
        title: Text('Return Goods', style: AppTypography.headline),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load purchase order.',
                type: BannerType.error),
          ),
        ),
        data: (data) => returnedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load prior returns.',
                  type: BannerType.error),
            ),
          ),
          data: (returned) {
            final available = <String, double>{
              for (final it in data.items)
                it.id: it.qtyReceived - (returned[it.id] ?? 0),
            };
            final lines = data.items
                .where((i) => (available[i.id] ?? 0) > 0)
                .toList();
            if (lines.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding),
                  child: Text(
                      'Nothing available to return — no received quantity '
                      'remains on this order.',
                      textAlign: TextAlign.center,
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.textMuted)),
                ),
              );
            }
            _ensureInit(lines);
            if (!_init) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildForm(
                context, data.po, lines, available, returned);
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    PurchaseOrder po,
    List<PurchaseOrderItem> lines,
    Map<String, double> available,
    Map<String, double> returned,
  ) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.md),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('PO ${po.poNumber}',
                              style: AppTypography.subhead
                                  .copyWith(color: AppColors.textMuted)),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            AppInlineBanner(
                                message: _error!, type: BannerType.error),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          for (final line in lines) ...[
                            _LineCard(
                              line: line,
                              productName: _products[line.productId]?.name ??
                                  line.productId,
                              serialized: _isSerialized(line),
                              received: line.qtyReceived,
                              alreadyReturned: returned[line.id] ?? 0,
                              available: available[line.id] ?? 0,
                              qtyReturned: _qtyReturned[line.id]!,
                              imeiInput: _imeiInput[line.id]!,
                              imeis: _imeis[line.id]!,
                              targetImeiCount: _qty(line.id).toInt(),
                              onScanImei: () => _scanImei(line.id),
                              onAddImei: (v) => _addImei(line.id, v),
                              onRemoveImei: (v) => _removeImei(line.id, v),
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppTextField(
                            controller: _reason,
                            label: 'Reason',
                            prefixIcon: Icons.info_outline,
                            hint: 'e.g. damaged on arrival',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _notes,
                            label: 'Notes',
                            prefixIcon: Icons.notes,
                            hint: 'Optional',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _TotalBar(total: _liveTotal(lines)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: PermissionGate(
                    module: 'purchase',
                    action: 'update',
                    child: AppButton(
                      label: 'Confirm Return',
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: () => _submit(po, lines, available),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Return Total',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
              Text(formatPkr(total),
                  style: AppTypography.headline
                      .copyWith(color: AppColors.destructive)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.productName,
    required this.serialized,
    required this.received,
    required this.alreadyReturned,
    required this.available,
    required this.qtyReturned,
    required this.imeiInput,
    required this.imeis,
    required this.targetImeiCount,
    required this.onScanImei,
    required this.onAddImei,
    required this.onRemoveImei,
    required this.onChanged,
  });

  final PurchaseOrderItem line;
  final String productName;
  final bool serialized;
  final double received;
  final double alreadyReturned;
  final double available;
  final TextEditingController qtyReturned;
  final TextEditingController imeiInput;
  final List<String> imeis;
  final int targetImeiCount;
  final VoidCallback onScanImei;
  final ValueChanged<String> onAddImei;
  final ValueChanged<String> onRemoveImei;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(productName,
                style: AppTypography.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
                'Received ${_fmtQty(received)} · '
                'Returned ${_fmtQty(alreadyReturned)} · '
                'Available ${_fmtQty(available)}',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: qtyReturned,
              label: 'Return qty',
              prefixIcon: Icons.assignment_return,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => onChanged(),
            ),
            if (serialized) ...[
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('IMEIs',
                      style: AppTypography.footnote
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('${imeis.length} / $targetImeiCount captured',
                      style: AppTypography.caption.copyWith(
                        color: imeis.length == targetImeiCount &&
                                targetImeiCount > 0
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final imei in imeis)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.smartphone,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: Text(imei, style: AppTypography.footnote)),
                      GestureDetector(
                        onTap: () => onRemoveImei(imei),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.destructive),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: imeiInput,
                      label: 'Add IMEI',
                      prefixIcon: Icons.keyboard,
                      hint: 'Type then add',
                      textInputAction: TextInputAction.done,
                      onSubmitted: onAddImei,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.accent),
                    onPressed: () => onAddImei(imeiInput.text),
                  ),
                ],
              ),
              if (barcodeScanSupported) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Scan IMEI',
                  variant: AppButtonVariant.tinted,
                  icon: Icons.qr_code_scanner,
                  fullWidth: true,
                  onPressed: onScanImei,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
