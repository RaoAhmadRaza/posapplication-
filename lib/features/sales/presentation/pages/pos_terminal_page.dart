import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../sync/presentation/controllers/connectivity_controller.dart';
import '../../../sync/presentation/controllers/offline_products_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../inventory/presentation/controllers/categories_controller.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';
import '../../../inventory/presentation/controllers/stock_levels_controller.dart';
import '../../../inventory/domain/entities/category.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/entities/stock_level.dart';
import '../controllers/pos_cart_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/session_sales_provider.dart';
import '../widgets/pos/pos_banners.dart';
import '../widgets/pos/pos_cart_panel.dart';
import '../widgets/pos/pos_cart_sheet.dart';
import '../widgets/pos/pos_search_bar.dart';
import '../widgets/pos/product_grid.dart';
import '../widgets/sales_empty_state.dart';
import '../widgets/sales_scaffold.dart';
import 'customer_picker_sheet.dart';
import 'held_sales_sheet.dart';

/// Width of the cart column in the design's desktop three-panel layout.
const _kCartWidth = 360.0;

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
  bool _pulledOnce = false;
  String _query = '';
  String? _categoryId;
  int _heldCount = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshHeld());
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
    setState(() {
      _heldCount = list.length;
      if (hasAutoSaved && ref.read(posCartProvider).lines.isEmpty) {
        _showAutoSavedNote = true;
      }
    });
  }

  /// Keeps the 'Held · n' count honest after holding or resuming a sale.
  Future<void> _refreshHeld() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    final list = await ref.read(posCartProvider.notifier).loadHeld(branchId: branch.id);
    if (!mounted) return;
    setState(() => _heldCount = list.length);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text); // drives the offline cache query
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
  }

  Future<void> _openCustomerPicker() async {
    // Offline is cash-only by construction: no credit, so no customer needed, and
    // customer creation is a server write. Block it with a reason, don't queue it.
    final online = ref.read(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Offline: cash-only sales. Customer selection/creation needs a connection.'),
      ));
      return;
    }
    await showCustomerPicker(context);
  }

  Future<void> _openHeldSales() async {
    await showHeldSalesSheet(context, ref);
    await _refreshHeld();
  }

  void _openCartSheet(String branchId, String? sessionId) {
    showPosCartSheet(
      context,
      branchId: branchId,
      sessionId: sessionId,
      onPickCustomer: () {
        Navigator.of(context).pop();
        _openCustomerPicker();
      },
      heldCount: _heldCount,
      onOpenHeld: () {
        Navigator.of(context).pop();
        _openHeldSales();
      },
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
    final lum = context.lum;
    final branch = ref.watch(currentBranchProvider);
    final sessionState = ref.watch(sessionProvider);
    final cart = ref.watch(posCartProvider);
    final online = ref.watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
    // Offline: resolve product search + price from the local reference cache.
    final products = online
        ? ref.watch(productsProvider)
        : ref.watch(offlineProductSearchProvider(_query));
    final stockLevels = ref.watch(stockLevelsProvider).value ?? <StockLevel>[];

    if (branch == null) {
      return Scaffold(
        backgroundColor: lum.paper,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final session = sessionState.value;

    if (session == null && !sessionState.isLoading) {
      final router = GoRouter.of(context);
      Future.microtask(() {
        if (mounted) router.go('/sales/open');
      });
      return Scaffold(
        backgroundColor: lum.paper,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= kSalesWideBreakpoint;

    // Refresh the reference cache once per terminal open while online, so an
    // offline sale later has products/prices/customers to resolve from.
    if (online && !_pulledOnce) {
      _pulledOnce = true;
      Future.microtask(() => ref.read(syncActionsProvider).pull());
    }

    final stockMap = <String, StockLevel>{};
    for (final s in stockLevels) {
      if (s.warehouseId == null) stockMap[s.productId] = s;
    }

    // Categories only exist on the online payload — the offline product cache
    // carries no category at all, so the filter row is hidden rather than shown
    // empty or lying.
    final categories = online
        ? (ref.watch(categoriesProvider).value ?? const <Category>[])
        : const <Category>[];

    final catalogue = _Catalogue(
      searchCtrl: _searchCtrl,
      products: products,
      stockMap: stockMap,
      categories: categories,
      categoryId: _categoryId,
      onCategory: (id) => setState(() => _categoryId = id),
      onScan: _scanBarcode,
      onAdd: _addLine,
      online: online,
      cartQtyOf: (id) => cart.lines
          .where((l) => l.productId == id)
          .fold<double>(0, (s, l) => s + l.qty),
    );

    return Scaffold(
      backgroundColor: lum.paper,
      body: Column(
        children: [
          const SalesHeader(title: 'Point of sale'),
          if (session != null) PosSessionBanner(session: session),
          if (_showAutoSavedNote)
            PosAutoSavedNote(
              onDismiss: () => setState(() => _showAutoSavedNote = false),
            ),
          Expanded(
            child: SafeArea(
              top: false,
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: catalogue),
                        SizedBox(
                          width: _kCartWidth,
                          child: PosCartPanel(
                            cart: cart,
                            branchId: branch.id,
                            sessionId: session?.id,
                            onPickCustomer: _openCustomerPicker,
                            heldCount: _heldCount,
                            onOpenHeld: _openHeldSales,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned.fill(child: catalogue),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: PosViewCartBar(
                            itemCount: cart.totalItems,
                            total: cart.grandTotal,
                            onTap: () =>
                                _openCartSheet(branch.id, session?.id),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search, category filter and the product grid — the left/only panel.
class _Catalogue extends StatelessWidget {
  const _Catalogue({
    required this.searchCtrl,
    required this.products,
    required this.stockMap,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    required this.onScan,
    required this.onAdd,
    required this.online,
    required this.cartQtyOf,
  });

  final TextEditingController searchCtrl;
  final AsyncValue<List<Product>> products;
  final Map<String, StockLevel> stockMap;
  final List<Category> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final VoidCallback onScan;
  final void Function(Product) onAdd;

  /// Passed down so a missing stock level reads correctly in each mode.
  final bool online;
  final double Function(String) cartQtyOf;

  @override
  Widget build(BuildContext context) {
    // On narrow layouts the floating cart bar overlaps the grid; reserve room
    // so the last row is never trapped under it.
    final bottomInset =
        MediaQuery.sizeOf(context).width >= kSalesWideBreakpoint ? 18.0 : 92.0;
    final active = categories.where((c) => c.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final selectedChip =
        categoryId == null ? 0 : active.indexWhere((c) => c.id == categoryId) + 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: PosSearchBar(controller: searchCtrl, onScan: onScan),
        ),
        if (active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: AppFilterChips(
              labels: ['All', ...active.map((c) => c.name)],
              selected: selectedChip < 0 ? 0 : selectedChip,
              onSelected: (i) => onCategory(i == 0 ? null : active[i - 1].id),
            ),
          ),
        const SizedBox(height: 14),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SalesEmptyState(
              icon: LucideIcons.wifiOff,
              message: "We couldn't load the catalogue. Check the connection "
                  'and try the search again.',
            ),
            data: (list) {
              final filtered = categoryId == null
                  ? list
                  : list.where((p) => p.categoryId == categoryId).toList();
              if (filtered.isEmpty) {
                return SalesEmptyState(
                  icon: LucideIcons.package,
                  message: searchCtrl.text.isEmpty && categoryId == null
                      ? 'Search for a part, or scan its barcode.'
                      : 'No parts match that.',
                );
              }
              return ProductGrid(
                products: filtered,
                stockMap: stockMap,
                cartQtyOf: cartQtyOf,
                onAdd: onAdd,
                online: online,
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset),
              );
            },
          ),
        ),
      ],
    );
  }
}
