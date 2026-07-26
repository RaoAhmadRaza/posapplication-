import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
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
import '../widgets/purchasing_imei_capture.dart';

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

    showAppToast(context, 'Return ${result!.returnNumber} recorded.',
        type: BannerType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseOrderDetailProvider(widget.poId));
    final returnedAsync = ref.watch(poReturnedQtysProvider(widget.poId));

    return detail.when(
      loading: () => _scaffold(child: const _Loading()),
      error: (_, _) => _scaffold(
        child: AppErrorState(
          title: 'Unable to load order',
          body: 'The purchase order could not be loaded.',
          onRetry: () =>
              ref.invalidate(purchaseOrderDetailProvider(widget.poId)),
        ),
      ),
      data: (data) => returnedAsync.when(
        loading: () =>
            _scaffold(description: 'PO ${data.po.poNumber}', child: const _Loading()),
        error: (_, _) => _scaffold(
          description: 'PO ${data.po.poNumber}',
          child: AppErrorState(
            title: 'Unable to load returns',
            body: 'Prior returns for this order could not be loaded.',
            onRetry: () =>
                ref.invalidate(poReturnedQtysProvider(widget.poId)),
          ),
        ),
        data: (returned) {
          final available = <String, double>{
            for (final it in data.items)
              it.id: it.qtyReceived - (returned[it.id] ?? 0),
          };
          final lines =
              data.items.where((i) => (available[i.id] ?? 0) > 0).toList();
          if (lines.isEmpty) {
            return _scaffold(
              description: 'PO ${data.po.poNumber}',
              child: const AppEmptyState(
                icon: LucideIcons.undo2,
                title: 'Nothing available to return',
                body: 'No received quantity remains on this order.',
              ),
            );
          }
          _ensureInit(lines);
          if (!_init) {
            return _scaffold(
                description: 'PO ${data.po.poNumber}', child: const _Loading());
          }
          return _scaffold(
            description: 'PO ${data.po.poNumber}',
            child: _buildForm(context, data.po, lines, available, returned),
          );
        },
      ),
    );
  }

  Widget _scaffold({String? description, required Widget child}) =>
      AppDetailScaffold(
        eyebrow: 'Purchasing',
        title: 'Purchase return',
        description: description,
        child: child,
      );

  Widget _buildForm(
    BuildContext context,
    PurchaseOrder po,
    List<PurchaseOrderItem> lines,
    Map<String, double> available,
    Map<String, double> returned,
  ) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          AppInlineBanner(message: _error!, type: BannerType.error),
          const SizedBox(height: 16),
        ],
        for (final line in lines) ...[
          AppSectionCard(
            eyebrow: _products[line.productId]?.name ?? line.productId,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Received ${_fmtQty(line.qtyReceived)} · '
                  'Returned ${_fmtQty(returned[line.id] ?? 0)} · '
                  'Available ${_fmtQty(available[line.id] ?? 0)}',
                  style: AppTypography.caption
                      .copyWith(color: lum.textTertiary),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _qtyReturned[line.id]!,
                  label: 'Return qty',
                  prefixIcon: LucideIcons.undo2,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => setState(() {}),
                ),
                if (_isSerialized(line))
                  PurchasingImeiCapture(
                    imeis: _imeis[line.id]!,
                    input: _imeiInput[line.id]!,
                    target: _qty(line.id).toInt(),
                    met: _imeis[line.id]!.length == _qty(line.id).toInt(),
                    onAdd: (v) => _addImei(line.id, v),
                    onRemove: (v) => _removeImei(line.id, v),
                    onScan:
                        barcodeScanSupported ? () => _scanImei(line.id) : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        AppTextField(
          controller: _reason,
          label: 'Reason',
          prefixIcon: LucideIcons.messageSquare,
          hint: 'e.g. damaged on arrival',
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _notes,
          label: 'Notes',
          prefixIcon: LucideIcons.clipboardList,
          hint: 'Optional',
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total return value',
                style:
                    AppTypography.subhead.copyWith(color: lum.textSecondary)),
            AppMoneyText(_liveTotal(lines), color: lum.dangerText),
          ],
        ),
        const SizedBox(height: 16),
        PermissionGate(
          module: 'purchase',
          action: 'update',
          child: AppButton(
            label: 'Confirm return',
            variant: AppButtonVariant.destructive,
            loading: _submitting,
            fullWidth: true,
            onPressed: () => _submit(po, lines, available),
          ),
        ),
      ],
    );
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
}
