import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_product.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/failures/purchase_failure.dart';
import '../controllers/purchase_order_detail_provider.dart';
import '../controllers/purchase_orders_controller.dart';

/// Goods Receipt Note entry — receive open lines of a purchase order.
class GrnReceivePage extends ConsumerStatefulWidget {
  const GrnReceivePage({super.key, required this.poId});

  final String poId;

  @override
  ConsumerState<GrnReceivePage> createState() => _GrnReceivePageState();
}

class _GrnReceivePageState extends ConsumerState<GrnReceivePage> {
  final _notes = TextEditingController();
  final Map<String, TextEditingController> _qtyReceived = {};
  final Map<String, TextEditingController> _qtyRejected = {};
  final Map<String, TextEditingController> _batch = {};
  final Map<String, TextEditingController> _imeiInput = {};
  final Map<String, DateTime?> _expiry = {};
  final Map<String, List<String>> _imeis = {};
  final Map<String, Product> _products = {};

  bool _init = false;
  bool _initializing = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    for (final m in [_qtyReceived, _qtyRejected, _batch, _imeiInput]) {
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
      _qtyReceived[line.id] =
          TextEditingController(text: _fmtQty(line.qtyRemaining));
      _qtyRejected[line.id] = TextEditingController(text: '0');
      _batch[line.id] = TextEditingController();
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

  double _received(String lineId) =>
      double.tryParse(_qtyReceived[lineId]!.text.trim()) ?? 0;

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

  Future<void> _pickExpiry(String lineId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry[lineId] ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expiry[lineId] = picked);
  }

  Future<void> _receive(List<PurchaseOrderItem> lines) async {
    final items = <Map<String, dynamic>>[];
    for (final line in lines) {
      final recv = _received(line.id);
      if (recv <= 0) continue; // skip lines left at 0
      final rej = double.tryParse(_qtyRejected[line.id]!.text.trim()) ?? 0;
      if (rej < 0) {
        setState(() => _error = 'Rejected quantity cannot be negative.');
        return;
      }
      if (recv + rej > line.qtyRemaining) {
        setState(() => _error =
            'Received + rejected exceeds remaining (${_fmtQty(line.qtyRemaining)}) for a line.');
        return;
      }
      final imeis = _imeis[line.id]!;
      if (_isSerialized(line) && imeis.length < recv) {
        setState(() => _error =
            'Serialized line needs ${recv.toInt()} IMEIs — ${imeis.length} captured.');
        return;
      }
      final map = <String, dynamic>{
        'po_item_id': line.id,
        'qty_received': recv,
        'qty_rejected': rej,
        'batch_number': _clean(_batch[line.id]!),
        'expiry_date':
            _expiry[line.id] != null ? _fmtDate(_expiry[line.id]!) : null,
      };
      if (_isSerialized(line)) map['imei_ids'] = List<String>.from(imeis);
      items.add(map);
    }

    if (items.isEmpty) {
      setState(() =>
          _error = 'Enter a received quantity for at least one line.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final (result, failure) =
        await ref.read(purchaseOrdersProvider.notifier).receive(
              poId: widget.poId,
              notes: _clean(_notes),
              items: items,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _submitting = false);
      if (failure is PurchaseOverReceiptFailure) {
        setState(() => _error = failure.message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('GRN ${result!.grnNumber} — PO ${result.poStatus}')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseOrderDetailProvider(widget.poId));

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
        title: Text('Receive Goods', style: AppTypography.headline),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load purchase order.',
                type: BannerType.error),
          ),
        ),
        data: (data) {
          final openLines =
              data.items.where((i) => i.qtyRemaining > 0).toList();
          if (openLines.isEmpty) {
            return Center(
              child: Text('No open lines to receive.',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
            );
          }
          _ensureInit(openLines);
          if (!_init) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildForm(context, data.po.poNumber, openLines);
        },
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, String poNumber, List<PurchaseOrderItem> lines) {
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
                          Text('PO $poNumber',
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
                              productName:
                                  _products[line.productId]?.name ??
                                      line.productId,
                              serialized: _isSerialized(line),
                              qtyReceived: _qtyReceived[line.id]!,
                              qtyRejected: _qtyRejected[line.id]!,
                              batch: _batch[line.id]!,
                              imeiInput: _imeiInput[line.id]!,
                              imeis: _imeis[line.id]!,
                              expiry: _expiry[line.id],
                              targetImeiCount: _received(line.id).toInt(),
                              onScanImei: () => _scanImei(line.id),
                              onAddImei: (v) => _addImei(line.id, v),
                              onRemoveImei: (v) => _removeImei(line.id, v),
                              onPickExpiry: () => _pickExpiry(line.id),
                              onClearExpiry: () =>
                                  setState(() => _expiry[line.id] = null),
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: PermissionGate(
                    module: 'purchase',
                    action: 'update',
                    child: AppButton(
                      label: 'Receive',
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: () => _receive(lines),
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

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.productName,
    required this.serialized,
    required this.qtyReceived,
    required this.qtyRejected,
    required this.batch,
    required this.imeiInput,
    required this.imeis,
    required this.expiry,
    required this.targetImeiCount,
    required this.onScanImei,
    required this.onAddImei,
    required this.onRemoveImei,
    required this.onPickExpiry,
    required this.onClearExpiry,
    required this.onChanged,
  });

  final PurchaseOrderItem line;
  final String productName;
  final bool serialized;
  final TextEditingController qtyReceived;
  final TextEditingController qtyRejected;
  final TextEditingController batch;
  final TextEditingController imeiInput;
  final List<String> imeis;
  final DateTime? expiry;
  final int targetImeiCount;
  final VoidCallback onScanImei;
  final ValueChanged<String> onAddImei;
  final ValueChanged<String> onRemoveImei;
  final VoidCallback onPickExpiry;
  final VoidCallback onClearExpiry;
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
                style: AppTypography.body, maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Remaining: ${_fmtQty(line.qtyRemaining)}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: qtyReceived,
                    label: 'Received',
                    prefixIcon: Icons.inventory_2,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: qtyRejected,
                    label: 'Rejected',
                    prefixIcon: Icons.block,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: batch,
              label: 'Batch Number',
              prefixIcon: Icons.tag,
              hint: 'Optional',
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: onPickExpiry,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Row(
                children: [
                  const Icon(Icons.event,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    expiry != null
                        ? 'Expiry: ${_fmtDate(expiry!)}'
                        : 'Set expiry date (optional)',
                    style: AppTypography.footnote,
                  ),
                  if (expiry != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: onClearExpiry,
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textHint),
                    ),
                  ],
                ],
              ),
            ),
            if (serialized) ...[
              const Divider(
                  color: AppColors.separator, height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('IMEIs',
                      style: AppTypography.footnote
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('${imeis.length} / $targetImeiCount captured',
                      style: AppTypography.caption.copyWith(
                        color: imeis.length >= targetImeiCount &&
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.accent),
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

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
