import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/post_stock_movement.dart';
import '../../domain/usecases/load_stock_balances.dart';
import '../controllers/products_controller.dart';
import '../controllers/stock_levels_controller.dart';
import '../widgets/inventory_ui.dart';

class StockMovementFormPage extends ConsumerStatefulWidget {
  const StockMovementFormPage({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<StockMovementFormPage> createState() =>
      _StockMovementFormPageState();
}

class _StockMovementFormPageState
    extends ConsumerState<StockMovementFormPage> {
  String? _selectedProductId;
  final _targetQtyController = TextEditingController();
  final _unitCostController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  double _currentOnHand = 0;
  bool _loadingBalance = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _selectedProductId = widget.productId;
      _loadCurrentBalance();
    }
  }

  @override
  void dispose() {
    _targetQtyController.dispose();
    _unitCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    if (_selectedProductId == null) return;
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;

    setState(() {
      _loadingBalance = true;
      _error = null;
    });

    // Canonical stock lives at warehouse_id IS NULL — always read there.
    final (bals, failure) =
        await ref.read(loadStockBalancesUseCaseProvider).call(
              branchId: branch.id,
              productId: _selectedProductId,
              warehouseId: null,
            );

    if (!mounted) return;

    if (failure != null) {
      // Surface the failure — never present a failed read as zero stock.
      setState(() {
        _loadingBalance = false;
        _error = failure.message;
      });
      return;
    }

    // Genuine empty result means the product has no stock yet — 0 is correct.
    final bal = bals.isNotEmpty ? bals.first : null;
    setState(() {
      _loadingBalance = false;
      _currentOnHand = bal?.qtyOnHand ?? 0;
    });
  }

  Future<void> _post() async {
    final targetText = _targetQtyController.text.trim();
    final costText = _unitCostController.text.trim();

    if (_selectedProductId == null) {
      setState(() => _error = 'Select a product.');
      return;
    }

    final target = double.tryParse(targetText);
    if (target == null) {
      setState(() => _error = 'Enter a valid target quantity.');
      return;
    }
    if (target < 0) {
      setState(() => _error = 'Target quantity must be 0 or greater.');
      return;
    }

    final delta = target - _currentOnHand;
    if (delta == 0) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final costPerUnit = double.tryParse(costText) ?? 0;

    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() => _error = 'No branch selected.');
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    final (_, failure) = await ref.read(postStockMovementUseCaseProvider).call(
          branchId: branch.id,
          warehouseId: null,
          productId: _selectedProductId!,
          variantId: null,
          operationType: StockMovementType.openingBalance.dbValue,
          qtyChange: delta,
          costPerUnit: costPerUnit,
          referenceType: 'OPENING',
          referenceId: _selectedProductId!,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _posting = false;
        _error = failure is InsufficientStockFailure
            ? 'This adjustment would result in negative stock.'
            : failure.message;
      });
      return;
    }

    ref.invalidate(stockLevelsProvider);
    if (mounted) {
      showAppToast(context, 'Opening stock set.', type: BannerType.success);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    // SERVICE products are non-stock — exclude from the stock-movement picker.
    final activeProducts = products
        .where((p) => p.isActive && p.type != ProductType.service)
        .toList();
    final selectedProduct = activeProducts
        .where((p) => p.id == _selectedProductId)
        .firstOrNull;

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Set opening stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          AppSectionCard(
            eyebrow: 'Product',
            child: _ProductField(
              selected: selectedProduct,
              // Preset via constructor → locked read-only display.
              locked: widget.productId != null,
              onPick: () => _pickProduct(activeProducts),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Opening stock',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadingBalance)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  _CurrentBalanceRow(onHand: _currentOnHand),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  controller: _targetQtyController,
                  label: 'Target quantity',
                  prefixIcon: LucideIcons.flag,
                  hint: 'Desired on-hand after adjustment',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                if (_selectedProductId != null && !_loadingBalance) ...[
                  const SizedBox(height: 12),
                  _DeltaPreview(
                    current: _currentOnHand,
                    targetText: _targetQtyController.text.trim(),
                  ),
                ],
                const SizedBox(height: 16),
                AppMoneyField(
                  controller: _unitCostController,
                  label: 'Unit cost',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _notesController,
                  label: 'Note',
                  prefixIcon: LucideIcons.pencilLine,
                  hint: 'Optional',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Set opening stock',
            loading: _posting,
            onPressed: _post,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  void _pickProduct(List<Product> products) {
    showAppSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'Select product',
            subtitle: 'Pick the item to set opening stock for.',
          ),
          for (final p in products) ...[
            _ProductOption(
              product: p,
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() {
                  _selectedProductId = p.id;
                  _currentOnHand = 0;
                  _error = null;
                });
                _loadCurrentBalance();
              },
            ),
            if (p != products.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Product row inside the form: a clay well showing the chosen item. Tappable to
/// open the picker sheet unless [locked] (the product was preset by the caller).
class _ProductField extends StatelessWidget {
  const _ProductField({
    required this.selected,
    required this.locked,
    required this.onPick,
  });

  final Product? selected;
  final bool locked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final label = selected?.name ?? (locked ? 'Loading…' : 'Select a product');

    final well = ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(kInvItemIcon, size: 18, color: lum.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: selected != null ? lum.textPrimary : lum.g400,
              ),
            ),
          ),
          if (!locked)
            Icon(LucideIcons.chevronDown, size: 18, color: lum.g400),
        ],
      ),
    );

    if (locked) return well;

    return Semantics(
      button: true,
      label: 'Select product',
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: well,
      ),
    );
  }
}

/// A single product row in the picker sheet.
class _ProductOption extends StatelessWidget {
  const _ProductOption({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: product.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(kInvItemIcon, size: 18, color: lum.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTypography.body.copyWith(color: lum.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      style: AppTypography.caption.copyWith(color: lum.g400),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current on-hand line above the target field.
class _CurrentBalanceRow extends StatelessWidget {
  const _CurrentBalanceRow({required this.onHand});
  final double onHand;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final positive = onHand > 0;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(LucideIcons.package, size: 18, color: lum.g400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Current on-hand',
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
          ),
          Text(
            qtyLabel(onHand),
            style: AppTypography.headline.copyWith(
              color: positive ? lum.successText : lum.g400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live delta banner: how many units this adjustment adds or removes.
class _DeltaPreview extends StatelessWidget {
  const _DeltaPreview({required this.current, required this.targetText});
  final double current;
  final String targetText;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final target = double.tryParse(targetText);
    if (target == null) return const SizedBox.shrink();
    final delta = target - current;
    if (delta == 0) return const SizedBox.shrink();
    final isPositive = delta > 0;

    final tone = isPositive ? lum.successText : lum.dangerText;
    final fill = isPositive ? lum.successSoft : lum.dangerSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? LucideIcons.arrowUp : LucideIcons.arrowDown,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPositive ? 'Adding' : 'Reducing',
              style: AppTypography.footnote.copyWith(color: tone),
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${qtyLabel(delta)}',
            style: AppTypography.headline.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}
