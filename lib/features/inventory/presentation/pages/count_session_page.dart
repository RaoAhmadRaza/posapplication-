import 'dart:async';

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
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_item.dart';
import '../../domain/entities/stock_count_status.dart';
import '../../domain/usecases/load_count_items.dart';
import '../controllers/counts_controller.dart';
import '../controllers/products_controller.dart';

class CountSessionPage extends ConsumerStatefulWidget {
  const CountSessionPage({super.key, required this.countId});

  final String countId;

  @override
  ConsumerState<CountSessionPage> createState() => _CountSessionPageState();
}

class _CountSessionPageState extends ConsumerState<CountSessionPage> {
  List<StockCountItem>? _items;
  StockCount? _count;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _barcodeToProductId = {};
  final Map<String, String> _skuToProductId = {};
  final Map<String, GlobalKey> _itemKeys = {};
  final ScrollController _scrollController = ScrollController();
  String? _scanError;
  String? _error;
  bool _loading = true;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final (items, itemsFailure) = await ref.read(loadCountItemsUseCaseProvider).call(widget.countId);
    if (!mounted) return;
    if (itemsFailure != null) {
      setState(() { _loading = false; _error = itemsFailure.message; });
      return;
    }
    final counts = ref.read(countsProvider).value ?? <StockCount>[];
    final count = counts.where((c) => c.id == widget.countId).firstOrNull;
    setState(() {
      _items = items;
      _count = count;
      _loading = false;
      for (final item in items) {
        if (!_controllers.containsKey(item.id)) {
          final ctrl = TextEditingController(text: item.countedQty?.toString() ?? '');
          ctrl.addListener(() => _scheduleAutoSave(item.id, ctrl));
          _controllers[item.id] = ctrl;
        }
        _itemKeys[item.id] = GlobalKey();
      }
      _buildProductLookup();
    });
  }

  void _scheduleAutoSave(String itemId, TextEditingController ctrl) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || ctrl.text.isEmpty) return;
      final qty = double.tryParse(ctrl.text.trim());
      if (qty == null) return;
      _record(itemId, qty);
    });
  }

  void _buildProductLookup() {
    _barcodeToProductId.clear();
    _skuToProductId.clear();
    final products = ref.read(productsProvider).value ?? <Product>[];
    for (final p in products) {
      if (p.barcode != null && p.barcode!.isNotEmpty) {
        _barcodeToProductId[p.barcode!] = p.id;
      }
      if (p.sku.isNotEmpty) {
        _skuToProductId[p.sku] = p.id;
      }
    }
  }

  Future<void> _scanForCountItem() async {
    setState(() => _scanError = null);
    final code = await scanBarcode(context, title: 'Scan Count Item');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    if (!mounted) return;

    final items = _items;
    if (items == null) return;

    final productId = _barcodeToProductId[code] ?? _skuToProductId[code];
    if (productId == null) {
      setState(() => _scanError = 'Not in this count');
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scanError = null);
      });
      return;
    }

    final itemIndex = items.indexWhere((i) => i.productId == productId);
    if (itemIndex == -1) {
      setState(() => _scanError = 'Not in this count');
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scanError = null);
      });
      return;
    }

    final item = items[itemIndex];
    final key = _itemKeys[item.id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final offset = itemIndex * 140.0;
      _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    final ctrl = _controllers[item.id];
    ctrl?.selection = TextSelection(
      baseOffset: 0,
      extentOffset: ctrl.text.length,
    );
    FocusScope.of(context).requestFocus(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ctrl != null && _controllers.containsKey(item.id)) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  Future<void> _record(String itemId, double counted) async {
    try {
      await ref.read(countsProvider.notifier).recordItem(itemId, counted);
    } catch (_) {}
  }

  Future<void> _complete() async {
    final count = _count;
    if (count == null) return;
    final remaining = count.totalItems - count.itemsCounted;
    if (remaining > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Items Remaining'),
          content: Text('$remaining items not yet counted. Complete anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Counting')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final varianceCount = count.varianceCount;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Count'),
        content: Text(
          varianceCount > 0
              ? '$varianceCount items have variance. Completing will post reconciliation adjustments to stock.'
              : 'No variance detected. Complete the count?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _completing = true);
    try {
      await ref.read(countsProvider.notifier).complete(widget.countId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _completing = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _count != null && _count!.totalItems > 0
        ? _count!.itemsCounted / _count!.totalItems
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Count ${_count?.countNumber ?? '...'}', style: AppTypography.headline),
            Text(
              '${_count?.itemsCounted ?? 0}/${_count?.totalItems ?? 0} items',
              style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (barcodeScanSupported && _count?.status == StockCountStatus.inProgress)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
              onPressed: _scanForCountItem,
              tooltip: 'Scan product to count',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppInlineBanner(message: _error!, type: BannerType.error),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_count?.status == StockCountStatus.inProgress) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.fieldFill,
                                color: progress >= 1 ? AppColors.success : AppColors.accent,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                        child: AppInlineBanner(message: _error!, type: BannerType.error),
                      ),
                    if (_scanError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                        child: AppInlineBanner(message: _scanError!, type: BannerType.info),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                        itemCount: _items?.length ?? 0,
                        itemBuilder: (_, i) {
                          final item = _items![i];
                          final ctrl = _controllers[item.id]!;
                          final variance = item.variance;

                          return Padding(
                            key: _itemKeys[item.id],
                            padding: EdgeInsets.only(bottom: i < _items!.length - 1 ? AppSpacing.sm : 0),
                            child: AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Item ${item.productId.substring(0, 8)}...',
                                                style: AppTypography.body,
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'System: ${item.systemQty.toStringAsFixed(1)}',
                                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: AppTextField(
                                            controller: ctrl,
                                            label: 'Counted',
                                            prefixIcon: Icons.edit,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            hint: item.systemQty.toStringAsFixed(0),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (variance != null && variance != 0) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(AppRadius.chip),
                                        ),
                                        child: Text(
                                          'Variance: ${variance > 0 ? "+" : ""}${variance.toStringAsFixed(1)}',
                                          style: AppTypography.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_count?.status == StockCountStatus.inProgress)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.screenPadding),
                          child: PermissionGate(
                            module: 'inventory',
                            action: 'approve',
                            child: AppButton(
                              label: 'Complete Count',
                              loading: _completing,
                              onPressed: _complete,
                              fullWidth: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
