import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';
import '../../../inventory/presentation/controllers/stock_levels_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/entities/stock_level.dart';
import '../../domain/entities/cart_line.dart';
import '../controllers/pos_cart_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/session_sales_provider.dart';
import 'customer_picker_sheet.dart';
import 'held_sales_sheet.dart';

class PosTerminalPage extends ConsumerStatefulWidget {
  const PosTerminalPage({super.key});

  @override
  ConsumerState<PosTerminalPage> createState() => _PosTerminalPageState();
}

class _PosTerminalPageState extends ConsumerState<PosTerminalPage>
    with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _showAutoSavedNote = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _autoHoldIfNeeded();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoSaved();
      final session = ref.read(sessionProvider).value;
      if (session != null) {
        ref.invalidate(sessionSalesProvider(session.id));
      }
    }
  }

  void _autoHoldIfNeeded() {
    final cart = ref.read(posCartProvider);
    if (cart.lines.isEmpty) return;
    final branch = ref.read(currentBranchProvider);
    final session = ref.read(sessionProvider).value;
    if (branch == null) return;
    final now = DateTime.now();
    final label = 'Auto-saved ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    ref.read(posCartProvider.notifier).hold(
      branchId: branch.id,
      sessionId: session?.id,
      label: label,
    );
  }

  Future<void> _checkAutoSaved() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    final list = await ref.read(posCartProvider.notifier).loadHeld(branchId: branch.id);
    if (!mounted) return;
    final hasAutoSaved = list.any((h) => h.label.startsWith('Auto-saved '));
    if (hasAutoSaved && ref.read(posCartProvider).lines.isEmpty) {
      setState(() => _showAutoSavedNote = true);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(productsProvider.notifier).search(_searchCtrl.text);
    });
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context, title: 'Scan Product');
    if (code == null || code == BarcodeScanPage.manualEntrySentinel) return;
    _searchCtrl.text = code;
    ref.read(productsProvider.notifier).search(code);
  }

  void _addLine(Product product) {
    double price = product.sellingPrice;
    double taxPct = product.taxRate;
    if (product.taxInclusive && product.taxRate > 0) {
      price = product.sellingPrice / (1 + product.taxRate / 100);
    }
    ref.read(posCartProvider.notifier).addLine(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          barcode: product.barcode,
          qty: 1,
          unitPrice: price,
          taxPct: taxPct,
        );
    _searchCtrl.clear();
  }

  Future<void> _openCustomerPicker() async {
    await showCustomerPicker(context);
  }

  void _showCartSheet() {
    final session = ref.read(sessionProvider).value;
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: _CartSheet(sessionId: session?.id, branchId: branch.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final sessionState = ref.watch(sessionProvider);
    final cart = ref.watch(posCartProvider);
    final products = ref.watch(productsProvider);
    final stockLevels = ref.watch(stockLevelsProvider).value ?? <StockLevel>[];

    if (branch == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = sessionState.value;

    if (session == null && !sessionState.isLoading) {
      Future.microtask(() => context.go('/sales/open'));
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final wide = MediaQuery.of(context).size.width >= 768;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final stockMap = <String, StockLevel>{};
    for (final s in stockLevels) {
      if (s.warehouseId == null) stockMap[s.productId] = s;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('POS', style: AppTypography.headline),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.accent, size: 22),
            onPressed: () => context.push('/sales/history'),
            tooltip: 'Sales History',
          ),
          IconButton(
            icon: const Icon(Icons.pause_presentation, color: AppColors.accent, size: 22),
            onPressed: () async {
              await showHeldSalesSheet(context, ref);
            },
            tooltip: 'Resume Held Sale',
          ),
          PermissionGate(
            module: 'sales',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.keyboard_return, color: AppColors.accent, size: 22),
              onPressed: () => context.push('/sales/return'),
              tooltip: 'Sales Return',
            ),
          ),
          if (session != null)
            TextButton(
              onPressed: () => context.push('/sales/session/close'),
              child: Text('Close Register', style: AppTypography.footnote.copyWith(color: AppColors.destructive)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (session != null) _SessionBanner(session: session),
            if (_showAutoSavedNote)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                color: AppColors.success.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Auto-saved cart available — tap Resume to restore.',
                        style: AppTypography.footnote.copyWith(color: AppColors.success),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAutoSavedNote = false),
                      child: Icon(Icons.close, size: 16, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            _CustomerChip(
              customer: cart.customer,
              onTap: _openCustomerPicker,
            ),
            Expanded(
              child: wide || isLandscape
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _SearchPanel(
                            searchCtrl: _searchCtrl,
                            products: products,
                            stockMap: stockMap,
                            onScan: _scanBarcode,
                            onAddLine: _addLine,
                          ),
                        ),
                        Container(width: 0.5, color: AppColors.separator),
                        Expanded(
                          flex: 3,
                          child: _CartPanel(cart: cart, sessionId: session?.id, branchId: branch.id),
                        ),
                      ],
                    )
                  : _SearchPanel(
                      searchCtrl: _searchCtrl,
                      products: products,
                      stockMap: stockMap,
                      onScan: _scanBarcode,
                      onAddLine: _addLine,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: wide || isLandscape
          ? null
          : cart.lines.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _showCartSheet,
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(
                    '${cart.lines.length} · ${formatPkr(cart.grandTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
    );
  }
}

class _SessionBanner extends ConsumerWidget {
  const _SessionBanner({required this.session});
  final dynamic session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openedAt = session.openedAt;
    final relative = openedAt != null ? _relativeTime(openedAt) : '';
    final isStale = _isStale();
    final salesAsync = ref.watch(sessionSalesProvider(session.id));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      color: isStale ? AppColors.warning.withValues(alpha: 0.08) : AppColors.accent.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            isStale ? Icons.warning_amber_rounded : Icons.point_of_sale,
            size: 16,
            color: isStale ? AppColors.warning : AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Open since $relative',
              style: AppTypography.footnote.copyWith(
                color: isStale ? AppColors.warning : AppColors.accent,
              ),
            ),
          ),
          if (isStale) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stale — close to reconcile',
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            salesAsync.when(
              data: (v) => 'Sales: ${formatPkr(v)}',
              loading: () => 'Sales: …',
              error: (_, _) => 'Sales: —',
            ),
            style: AppTypography.footnote.copyWith(
              color: salesAsync.hasError
                  ? AppColors.destructive
                  : (isStale ? AppColors.warning : AppColors.accent),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isStale() {
    if (session == null || session.openedAt == null) return false;
    final opened = session.openedAt as DateTime;
    return DateTime.now().difference(opened).inHours > 12;
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({required this.customer, required this.onTap});
  final dynamic customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = customer?.name ?? 'Walk-in';
    final isWalkIn = customer == null;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
        color: isWalkIn ? AppColors.fieldFill : AppColors.accent.withValues(alpha: 0.06),
        child: Row(
          children: [
            Icon(
              isWalkIn ? Icons.person_outline : Icons.person,
              size: 18,
              color: isWalkIn ? AppColors.textMuted : AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isWalkIn ? 'Walk-in' : name.toString(),
              style: AppTypography.footnote.copyWith(
                color: isWalkIn ? AppColors.textMuted : AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.searchCtrl,
    required this.products,
    required this.stockMap,
    required this.onScan,
    required this.onAddLine,
  });

  final TextEditingController searchCtrl;
  final AsyncValue<List<Product>> products;
  final Map<String, StockLevel> stockMap;
  final VoidCallback onScan;
  final void Function(Product) onAddLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, 0),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: searchCtrl,
                  label: 'Product',
                  prefixIcon: Icons.search,
                  hint: 'Search name, SKU, or barcode',
                ),
              ),
              if (barcodeScanSupported) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 22),
                    onPressed: onScan,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Search failed', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    searchCtrl.text.isEmpty ? 'Search for products' : 'No products found',
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final stock = stockMap[p.id];
                  return _SearchResultTile(
                    product: p,
                    stock: stock,
                    onTap: (stock?.available ?? 0) > 0 ? () => onAddLine(p) : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.product, this.stock, required this.onTap});
  final Product product;
  final StockLevel? stock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = stock?.available ?? 0;
    final outOfStock = stock == null || available <= 0;
    final lowStock = stock != null && available > 0 && available <= product.reorderPoint;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: outOfStock ? 0.45 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                    style: AppTypography.footnote.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(product.name, style: AppTypography.headline, overflow: TextOverflow.ellipsis),
                        ),
                        if (outOfStock) ...[
                          const SizedBox(width: 6),
                          _StockChip(label: 'Out', color: AppColors.destructive),
                        ] else if (lowStock) ...[
                          const SizedBox(width: 6),
                          _StockChip(label: 'Low', color: AppColors.warning),
                        ] else if (stock != null) ...[
                          const SizedBox(width: 6),
                          _StockChip(label: '${available.toStringAsFixed(0)}', color: AppColors.textMuted),
                        ],
                      ],
                    ),
                    Text(product.sku, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                formatPkr(product.sellingPrice),
                style: AppTypography.headline.copyWith(color: AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({required this.cart, this.sessionId, required this.branchId});
  final CartState cart;
  final String? sessionId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: cart.lines.isEmpty
              ? Center(
                  child: Text(
                    'Cart is empty',
                    style: AppTypography.subhead.copyWith(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                  itemCount: cart.lines.length,
                  itemBuilder: (_, i) => _CartLineRow(
                    line: cart.lines[i],
                    onRemove: () => ref.read(posCartProvider.notifier).removeLine(cart.lines[i].id),
                    onQtyChanged: (q) => ref.read(posCartProvider.notifier).updateQty(cart.lines[i].id, q),
                  ),
                ),
        ),
        if (cart.lines.isNotEmpty) _CartFooter(cart: cart, sessionId: sessionId, branchId: branchId),
      ],
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line, required this.onRemove, required this.onQtyChanged});
  final CartLine line;
  final VoidCallback onRemove;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName, style: AppTypography.headline),
                const SizedBox(height: 2),
                Text(
                  formatPkr(line.unitPrice),
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: AppColors.textMuted, size: 24),
                onPressed: line.qty > 1 ? () => onQtyChanged(line.qty - 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  line.qty.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppColors.accent, size: 24),
                onPressed: () => onQtyChanged(line.qty + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(
            width: 80,
            child: Text(
              formatPkr(line.lineTotal),
              textAlign: TextAlign.right,
              style: AppTypography.headline.copyWith(color: AppColors.accent),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textHint, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _CartFooter extends ConsumerWidget {
  const _CartFooter({required this.cart, this.sessionId, required this.branchId});
  final CartState cart;
  final String? sessionId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: Column(
        children: [
          _FooterRow(label: 'Subtotal', value: cart.subtotal, muted: true),
          if (cart.discountTotal > 0) _FooterRow(label: 'Discount', value: -cart.discountTotal, muted: true),
          if (cart.taxTotal > 0) _FooterRow(label: 'Tax', value: cart.taxTotal, muted: true),
          _FooterRow(label: 'Total', value: cart.grandTotal, bold: true),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Charge ${formatPkr(cart.grandTotal)}',
            onPressed: cart.lines.isEmpty
                ? null
                : () => context.push('/sales/payment', extra: {'branchId': branchId, 'sessionId': sessionId}),
            fullWidth: true,
            icon: Icons.payment,
          ),
          if (cart.lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Hold',
              onPressed: () => _hold(context, ref),
              fullWidth: true,
              variant: AppButtonVariant.plain,
              icon: Icons.pause_circle_outline,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final labelCtrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Sale'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(hintText: 'Label (e.g. Customer name)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, labelCtrl.text.trim().isEmpty ? 'Held sale' : labelCtrl.text.trim()),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
    if (label == null || !context.mounted) return;
    final ok = await ref.read(posCartProvider.notifier).hold(
      branchId: branchId,
      sessionId: sessionId,
      label: label,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale held: $label'), duration: const Duration(seconds: 2)),
      );
    }
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.label, required this.value, this.bold = false, this.muted = false});
  final String label;
  final double value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: (bold ? AppTypography.headline : AppTypography.footnote).copyWith(
            color: muted ? AppColors.textMuted : AppColors.textPrimary,
          )),
          Text(
            formatPkr(value),
            style: (bold ? AppTypography.headline : AppTypography.footnote).copyWith(
              color: muted ? AppColors.textMuted : AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSheet extends ConsumerWidget {
  const _CartSheet({this.sessionId, required this.branchId});
  final String? sessionId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    return Column(
      children: [
        AppBar(
          title: Text('Cart', style: AppTypography.headline),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        _CustomerChip(
          customer: cart.customer,
          onTap: () async {
            Navigator.of(context).pop();
            await showCustomerPicker(context);
          },
        ),
        Expanded(
          child: cart.lines.isEmpty
              ? Center(
                  child: Text('Cart is empty', style: AppTypography.subhead.copyWith(color: AppColors.textHint)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
                  itemCount: cart.lines.length,
                  itemBuilder: (_, i) => _CartLineRow(
                    line: cart.lines[i],
                    onRemove: () => ref.read(posCartProvider.notifier).removeLine(cart.lines[i].id),
                    onQtyChanged: (q) => ref.read(posCartProvider.notifier).updateQty(cart.lines[i].id, q),
                  ),
                ),
        ),
        if (cart.lines.isNotEmpty) _CartFooter(cart: cart, sessionId: sessionId, branchId: branchId),
      ],
    );
  }
}
