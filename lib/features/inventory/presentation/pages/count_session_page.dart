import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_item.dart';
import '../../domain/entities/stock_count_status.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_count_items.dart';
import '../controllers/counts_controller.dart';
import '../controllers/products_controller.dart';
import '../widgets/inventory_ui.dart';

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
    // SERVICE products are non-stock — exclude from the count scan/sku lookup.
    final products = (ref.read(productsProvider).value ?? <Product>[])
        .where((p) => p.type != ProductType.service)
        .toList();
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
    final code = await scanBarcode(context, title: 'Scan Count Item');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    if (!mounted) return;

    final items = _items;
    if (items == null) return;

    final productId = _barcodeToProductId[code] ?? _skuToProductId[code];
    final itemIndex = productId == null
        ? -1
        : items.indexWhere((i) => i.productId == productId);
    if (itemIndex == -1) {
      showAppToast(context, 'Not in this count');
      return;
    }

    final item = items[itemIndex];
    final ctx = _itemKeys[item.id]?.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    final ctrl = _controllers[item.id];
    if (ctrl != null) {
      ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    }
  }

  Future<void> _record(String itemId, double counted) async {
    try {
      await ref.read(countsProvider.notifier).recordItem(itemId, counted);
    } on InventoryFailure catch (f) {
      if (!mounted) return;
      showAppToast(context, f.message);
      // Keep the user on the field with the typed qty selected, to retry.
      final ctrl = _controllers[itemId];
      if (ctrl != null) {
        ctrl.selection =
            TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
      }
    }
  }

  Future<void> _complete() async {
    final count = _count;
    if (count == null) return;

    final remaining = count.totalItems - count.itemsCounted;
    if (remaining > 0) {
      final ok = await showAppConfirm(
        context,
        title: 'Items remaining',
        message: '$remaining items not yet counted. Complete anyway?',
        confirmLabel: 'Complete',
        cancelLabel: 'Keep counting',
      );
      if (!ok || !mounted) return;
    }

    final varianceCount = count.varianceCount;
    final ok = await showAppConfirm(
      context,
      title: 'Complete count',
      message: varianceCount > 0
          ? '$varianceCount items have variance. Completing will post reconciliation adjustments to stock.'
          : 'No variance detected. Complete the count?',
      confirmLabel: 'Complete',
    );
    if (!ok || !mounted) return;

    setState(() => _completing = true);
    try {
      await ref.read(countsProvider.notifier).complete(widget.countId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      showAppToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final inProgress = count?.status == StockCountStatus.inProgress;

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Count session',
      description:
          '${count?.itemsCounted ?? 0} of ${count?.totalItems ?? 0} counted',
      actions: [
        if (barcodeScanSupported && inProgress) _ScanAction(onTap: _scanForCountItem),
      ],
      child: _buildBody(inProgress),
    );
  }

  Widget _buildBody(bool inProgress) {
    if (_loading) return const AppListSkeleton();
    if (_error != null && _items == null) {
      return AppErrorState(
        title: "Unable to load this count",
        body: _error!,
        onRetry: _load,
      );
    }

    final items = _items ?? const <StockCountItem>[];
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final byId = {for (final p in products) p.id: p};

    return Column(
      children: [
        for (final item in items) ...[
          _CountItemCard(
            key: _itemKeys[item.id],
            item: item,
            product: byId[item.productId],
            controller: _controllers[item.id]!,
          ),
          if (item != items.last) const SizedBox(height: 10),
        ],
        if (inProgress) ...[
          const SizedBox(height: 20),
          PermissionGate(
            module: 'inventory',
            action: 'approve',
            child: AppButton(
              label: 'Complete count',
              loading: _completing,
              onPressed: _complete,
              fullWidth: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// Clay icon button used as a header action to scan-and-jump to a count line.
class _ScanAction extends StatelessWidget {
  const _ScanAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Scan product to count',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(LucideIcons.scanLine, size: 20, color: lum.accent),
        ),
      ),
    );
  }
}

class _CountItemCard extends StatelessWidget {
  const _CountItemCard({
    super.key,
    required this.item,
    required this.product,
    required this.controller,
  });

  final StockCountItem item;
  final Product? product;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final name = product?.name ?? 'Item ${item.productId.substring(0, 8)}';
    final sku = product?.sku ?? '—';
    final pill = _variancePill();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 42,
            height: 42,
            child: Center(child: Icon(kInvItemIcon, size: 19, color: lum.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '$sku · expected ${qtyLabel(item.systemQty)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoValue.copyWith(fontSize: 12, color: lum.g500),
                ),
                if (pill != null) ...[
                  const SizedBox(height: 8),
                  pill,
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: AppTextField(
              controller: controller,
              label: 'Counted',
              prefixIcon: LucideIcons.hash,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              hint: qtyLabel(item.systemQty),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _variancePill() {
    final counted = item.countedQty;
    if (counted == null) return null;
    final delta = counted - item.systemQty;
    if (delta == 0) {
      return const AppPill(label: 'Match', tone: AppPillTone.success);
    }
    if (delta > 0) {
      return AppPill(label: '+${qtyLabel(delta)}', tone: AppPillTone.success);
    }
    return AppPill(label: '-${qtyLabel(delta.abs())}', tone: AppPillTone.warning);
  }
}
