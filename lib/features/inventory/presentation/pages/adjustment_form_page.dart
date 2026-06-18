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
import '../../domain/entities/warehouse.dart';
import '../../domain/entities/adjustment_reason.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/ensure_default_warehouse.dart';
import '../controllers/adjustments_controller.dart';
import '../controllers/products_controller.dart';
import '../controllers/warehouses_controller.dart';

class AdjustmentFormPage extends ConsumerStatefulWidget {
  const AdjustmentFormPage({super.key});

  @override
  ConsumerState<AdjustmentFormPage> createState() => _AdjustmentFormPageState();
}

class _AdjustmentFormPageState extends ConsumerState<AdjustmentFormPage> {
  String? _selectedProductId;
  String? _selectedWarehouseId;
  final _qtyController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  AdjustmentReason _reason = AdjustmentReason.damage;
  String? _error;
  bool _posting = false;
  StockAdjustment? _result;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initDefaults);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initDefaults() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    final (wh, _) = await ref.read(ensureDefaultWarehouseUseCaseProvider).call(branch.id);
    if (mounted) setState(() => _selectedWarehouseId = wh?.id);
  }

  Future<void> _submit() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;

    if (_selectedProductId == null) {
      setState(() => _error = 'Select a product.');
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty == 0) {
      setState(() => _error = 'Enter a non-zero quantity.');
      return;
    }
    final costPerUnit = double.tryParse(_costController.text.trim()) ?? 0;

    setState(() {
      _posting = true;
      _error = null;
      _result = null;
    });

    final (adjustment, failure) = await ref.read(adjustmentsProvider.notifier).create(
          branchId: branch.id,
          warehouseId: _selectedWarehouseId,
          productId: _selectedProductId!,
          variantId: null,
          adjQty: qty,
          costPerUnit: costPerUnit,
          reasonCode: _reason.dbValue,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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

    setState(() {
      _posting = false;
      _result = adjustment;
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];
    final activeProducts = products.where((p) => p.isActive).toList();
    final selectedProduct = activeProducts.where((p) => p.id == _selectedProductId).firstOrNull;
    final selectedWarehouse = warehouses.where((w) => w.id == _selectedWarehouseId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Adjustment', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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
                onChanged: (p) => setState(() {
                  _selectedProductId = p.id;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              _WarehousePicker(
                warehouses: warehouses,
                selected: selectedWarehouse,
                onChanged: (w) => setState(() {
                  _selectedWarehouseId = w.id;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _qtyController,
                label: 'Quantity',
                prefixIcon: Icons.exposure,
                hint: 'Positive = add, Negative = remove',
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _costController,
                label: 'Cost per Unit',
                prefixIcon: Icons.attach_money,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              _ReasonDropdown(
                value: _reason,
                onChanged: (r) => setState(() {
                  _reason = r;
                  if (r == AdjustmentReason.writeOff) {
                    final current = double.tryParse(_qtyController.text.trim()) ?? 0;
                    if (current >= 0) {
                      _qtyController.text = current == 0 ? '-1' : '${-current.abs()}';
                    }
                  }
                }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _notesController,
                label: 'Notes',
                prefixIcon: Icons.edit_note,
                hint: 'Optional',
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: _result != null ? 'Done' : 'Create Adjustment',
                loading: _posting,
                onPressed: _result != null ? () => Navigator.of(context).pop() : _submit,
                fullWidth: true,
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineBanner(
                  message: _result!.requiresApproval
                      ? 'Submitted for approval. An admin must approve before posting.'
                      : 'Adjustment posted successfully.',
                  type: _result!.requiresApproval ? BannerType.info : BannerType.success,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.products, required this.selected, required this.onChanged});
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
                    style: selected != null ? AppTypography.body : AppTypography.fieldHint,
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
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 5, decoration: BoxDecoration(
              color: AppColors.separator, borderRadius: BorderRadius.circular(2.5))),
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
                      child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: AppTypography.body.copyWith(color: AppColors.accent)),
                    ),
                    title: Text(p.name, style: AppTypography.body),
                    subtitle: Text('SKU: ${p.sku}', style: AppTypography.caption),
                    selected: selected?.id == p.id,
                    onTap: () { Navigator.of(ctx).pop(); onChanged(p); },
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

class _WarehousePicker extends StatelessWidget {
  const _WarehousePicker({required this.warehouses, required this.selected, required this.onChanged});
  final List<Warehouse> warehouses;
  final Warehouse? selected;
  final ValueChanged<Warehouse> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Warehouse (optional)', style: AppTypography.fieldLabel),
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
                Icon(Icons.warehouse, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected?.name ?? 'None (branch default)',
                    style: selected != null ? AppTypography.body : AppTypography.fieldHint,
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.business, size: 20),
              title: const Text('None (branch default)'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            ...warehouses.where((w) => w.isActive).map((w) => ListTile(
              leading: const Icon(Icons.warehouse, size: 20),
              title: Text(w.name),
              subtitle: Text(w.code, style: AppTypography.caption),
              trailing: w.isDefault ? const Icon(Icons.star, size: 16, color: AppColors.accent) : null,
              onTap: () { Navigator.of(ctx).pop(); onChanged(w); },
            )),
          ],
        ),
      ),
    );
  }
}

class _ReasonDropdown extends StatelessWidget {
  const _ReasonDropdown({required this.value, required this.onChanged});
  final AdjustmentReason value;
  final ValueChanged<AdjustmentReason> onChanged;

  @override
  Widget build(BuildContext context) {
    final reasons = [
      AdjustmentReason.damage,
      AdjustmentReason.theft,
      AdjustmentReason.expired,
      AdjustmentReason.recount,
      AdjustmentReason.writeOff,
      AdjustmentReason.other,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Reason', style: AppTypography.fieldLabel),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AdjustmentReason>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
              items: reasons.map((r) => DropdownMenuItem(
                value: r,
                child: Text(r.dbValue.replaceAll('_', ' '), style: AppTypography.body),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}
