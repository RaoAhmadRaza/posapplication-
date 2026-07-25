import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/services/scanner_support.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/voice_support.dart';
import '../../../../core/services/voxa_stt_service.dart';
import '../../../../core/widgets/barcode_scan_page.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../sync/presentation/controllers/connectivity_controller.dart';
import '../../../sync/presentation/controllers/offline_products_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../inventory/presentation/controllers/categories_controller.dart';
import '../controllers/pos_products_controller.dart';
import '../../../inventory/domain/usecases/search_products.dart';
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

/// Stock filter for the POS grid. Mirrors the tile's stock classification.
enum PosStockFilter { all, low, out }

class PosTerminalPage extends ConsumerStatefulWidget {
  const PosTerminalPage({super.key});

  @override
  ConsumerState<PosTerminalPage> createState() => _PosTerminalPageState();
}

class _PosTerminalPageState extends ConsumerState<PosTerminalPage>
    with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _gridScrollCtrl = ScrollController();
  final _voiceService = VoiceInputService();
  bool _voiceListening = false;
  bool _loadingMore = false;
  Timer? _debounce;
  bool _showAutoSavedNote = false;
  bool _pulledOnce = false;
  String _query = '';
  String? _categoryId;
  PosStockFilter _stockFilter = PosStockFilter.all;
  int _heldCount = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _gridScrollCtrl.addListener(_onGridScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshHeld());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _gridScrollCtrl.dispose();
    _voiceService.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isOnline => ref
      .read(connectivityProvider)
      .maybeWhen(data: (v) => v, orElse: () => true);

  void _onGridScroll() {
    if (_loadingMore || !_isOnline) return;
    final notifier = ref.read(posProductsProvider.notifier);
    if (!notifier.hasMore) return;
    final pos = _gridScrollCtrl.position;
    if (pos.pixels < pos.maxScrollExtent - 400) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await ref.read(posProductsProvider.notifier).loadMore();
    if (!mounted) return;
    setState(() => _loadingMore = false);
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
      // POS search is independent of the inventory productsProvider so POS and
      // the catalog page never cross-filter. Offline reads the query family;
      // online drives POS's own paginated ProductsController instance.
      setState(() => _query = _searchCtrl.text);
      if (_isOnline) {
        ref.read(posProductsProvider.notifier).search(_searchCtrl.text);
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await scanProductCode(context, title: 'Scan Product');
    if (!mounted || code == null) return;
    if (code == barcodeNoCodeFoundSentinel) {
      _snack('No barcode or QR found in that image');
      return;
    }

    // Exact barcode/SKU match → add to the cart immediately (POS "beep & add").
    // Otherwise fall back to filling the search so the user can pick.
    final online = ref
        .read(connectivityProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    List<Product> results;
    if (online) {
      final (rows, failure) =
          await ref.read(searchProductsUseCaseProvider).call(code);
      results = failure == null ? rows : const [];
    } else {
      results = await ref.read(offlineProductSearchProvider(code).future);
    }
    if (!mounted) return;

    final exact =
        results.where((p) => p.barcode == code || p.sku == code).toList();
    if (exact.length == 1) {
      _addLine(exact.first);
      _snack('Added ${exact.first.name}');
      return;
    }
    _searchCtrl.text = code; // listener runs the filtered search
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startVoice() async {
    // Windows/Linux: record → Voxa transcribe on the second tap (no live partials).
    if (voiceSearchCloudSupported) {
      if (VoxaStt.instance.isRecording) {
        final text = await VoxaStt.instance.stopAndTranscribe();
        if (!mounted) return;
        setState(() => _voiceListening = false);
        if (text != null) {
          _searchCtrl.text = text;
        } else {
          _snack('Voice service unavailable — is Voxa running?');
        }
        return;
      }
      final ok = await VoxaStt.instance.startRecording();
      if (!mounted) return;
      setState(() => _voiceListening = ok);
      if (!ok) _snack('Microphone permission needed');
      return;
    }
    // iOS/Android/macOS: on-device speech_to_text with live partials.
    if (_voiceListening) {
      _voiceService.cancel();
      setState(() => _voiceListening = false);
      return;
    }
    setState(() => _voiceListening = true);
    final result = await _voiceService.listen(
      onPartial: (partial) {
        if (mounted) _searchCtrl.text = partial;
      },
    );
    if (!mounted) return;
    setState(() => _voiceListening = false);
    if (result != null && result.isNotEmpty) _searchCtrl.text = result;
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
        ? ref.watch(posProductsProvider)
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
      scrollController: online ? _gridScrollCtrl : null,
      products: products,
      stockMap: stockMap,
      categories: categories,
      categoryId: _categoryId,
      onCategory: (id) => setState(() => _categoryId = id),
      stockFilter: _stockFilter,
      onStockFilter: (f) => setState(() => _stockFilter = f),
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
          SalesHeader(
            title: 'Point of sale',
            actions: [
              if (voiceSearchSupported)
                IconButton(
                  icon: Icon(
                    _voiceListening ? LucideIcons.mic : LucideIcons.micOff,
                    size: 22,
                    color: _voiceListening ? lum.accent : null,
                  ),
                  tooltip: 'Voice search',
                  onPressed: _startVoice,
                ),
              if (barcodeScanSupported || barcodeImageScanSupported)
                IconButton(
                  icon: const Icon(LucideIcons.qrCode, size: 22),
                  tooltip: 'Scan product',
                  onPressed: _scanBarcode,
                ),
            ],
          ),
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
    required this.scrollController,
    required this.products,
    required this.stockMap,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    required this.stockFilter,
    required this.onStockFilter,
    required this.onScan,
    required this.onAdd,
    required this.online,
    required this.cartQtyOf,
  });

  final TextEditingController searchCtrl;
  final ScrollController? scrollController;
  final AsyncValue<List<Product>> products;
  final Map<String, StockLevel> stockMap;
  final List<Category> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final PosStockFilter stockFilter;
  final ValueChanged<PosStockFilter> onStockFilter;
  final VoidCallback onScan;
  final void Function(Product) onAdd;

  /// Passed down so a missing stock level reads correctly in each mode.
  final bool online;
  final double Function(String) cartQtyOf;

  /// Whether [p] matches the active stock filter. Mirrors ProductTile's
  /// classification: online, a missing stock row means none on hand.
  bool _matchesStock(Product p, StockLevel? s) {
    final available = s?.available ?? 0;
    final out = s == null ? online : available <= 0;
    final low = s != null && available > 0 && available <= p.reorderPoint;
    return stockFilter == PosStockFilter.out ? out : low;
  }

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
        // Stock filter — online only; offline stock is uncached, so Low/Out
        // can't be resolved (same reason categories are hidden offline).
        if (online)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: AppFilterChips(
              labels: const ['All', 'Low', 'Out of stock'],
              selected: stockFilter.index,
              onSelected: (i) => onStockFilter(PosStockFilter.values[i]),
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
              var filtered = categoryId == null
                  ? list
                  : list.where((p) => p.categoryId == categoryId).toList();
              if (stockFilter != PosStockFilter.all) {
                filtered = filtered
                    .where((p) => _matchesStock(p, stockMap[p.id]))
                    .toList();
              }
              if (filtered.isEmpty) {
                return SalesEmptyState(
                  icon: LucideIcons.package,
                  message: searchCtrl.text.isEmpty &&
                          categoryId == null &&
                          stockFilter == PosStockFilter.all
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
                scrollController: scrollController,
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset),
              );
            },
          ),
        ),
      ],
    );
  }
}
