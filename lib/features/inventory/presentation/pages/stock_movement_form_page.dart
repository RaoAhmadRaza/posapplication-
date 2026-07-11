import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement_type.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/post_stock_movement.dart';
import '../../domain/usecases/load_stock_balances.dart';
import '../controllers/products_controller.dart';
import '../controllers/stock_levels_controller.dart';

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
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final activeProducts = products.where((p) => p.isActive).toList();
    final selectedProduct = activeProducts
        .where((p) => p.id == _selectedProductId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Set Opening Stock', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                AppInlineBanner(message: _error!, type: BannerType.error),
                const SizedBox(height: AppSpacing.lg),
              ],
              _ProductPicker(
                products: activeProducts,
                selected: selectedProduct,
                onChanged: (p) {
                  setState(() {
                    _selectedProductId = p.id;
                    _currentOnHand = 0;
                    _error = null;
                  });
                  _loadCurrentBalance();
                },
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              if (_loadingBalance)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
                )
              else ...[
                _CurrentBalanceLabel(onHand: _currentOnHand),
                const SizedBox(height: AppSpacing.fieldGap),
              ],
              AppTextField(
                controller: _targetQtyController,
                label: 'Target Quantity',
                prefixIcon: Icons.flag,
                hint: 'Desired on-hand after adjustment',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _unitCostController,
                label: 'Unit Cost',
                prefixIcon: Icons.attach_money,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _notesController,
                label: 'Note',
                prefixIcon: Icons.edit_note,
                hint: 'Optional',
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_selectedProductId != null && !_loadingBalance) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _DeltaPreview(
                    current: _currentOnHand,
                    targetText: _targetQtyController.text.trim(),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Set Opening Stock',
                loading: _posting,
                onPressed: _post,
                fullWidth: true,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentBalanceLabel extends StatelessWidget {
  const _CurrentBalanceLabel({required this.onHand});
  final double onHand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text('Current on-hand', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
          const Spacer(),
          Text(
            onHand.toStringAsFixed(onHand == onHand.roundToDouble() ? 0 : 1),
            style: AppTypography.headline.copyWith(
              color: onHand > 0 ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPreview extends StatelessWidget {
  const _DeltaPreview({required this.current, required this.targetText});
  final double current;
  final String targetText;

  @override
  Widget build(BuildContext context) {
    final target = double.tryParse(targetText);
    if (target == null) {
      return const SizedBox.shrink();
    }
    final delta = target - current;
    if (delta == 0) return const SizedBox.shrink();
    final isPositive = delta > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: isPositive ? AppColors.success : AppColors.destructive,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isPositive ? 'Adding' : 'Reducing',
            style: AppTypography.footnote.copyWith(
              color: isPositive ? AppColors.success : AppColors.destructive,
            ),
          ),
          const Spacer(),
          Text(
            isPositive ? '+$delta' : '$delta',
            style: AppTypography.headline.copyWith(
              color: isPositive ? AppColors.success : AppColors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.products,
    required this.selected,
    required this.onChanged,
  });

  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Product', style: AppTypography.fieldLabel),
        ),
        InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected?.name ?? 'Select a product',
                    style: selected != null
                        ? AppTypography.body
                        : AppTypography.fieldHint,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 5,
              decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Text('Select Product', style: AppTypography.subhead),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: AppTypography.body.copyWith(color: AppColors.accent),
                      ),
                    ),
                    title: Text(p.name, style: AppTypography.body),
                    subtitle: Text('SKU: ${p.sku}', style: AppTypography.caption),
                    selected: selected?.id == p.id,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onChanged(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
