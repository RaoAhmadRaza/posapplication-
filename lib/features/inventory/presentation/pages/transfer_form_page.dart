import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/domain/entities/branch.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/ensure_default_warehouse.dart';
import '../controllers/products_controller.dart';
import '../controllers/transfers_controller.dart';
import '../controllers/warehouses_controller.dart';

class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key});

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  String? _toBranchId;
  String? _fromWarehouseId;
  String? _toWarehouseId;
  final _notesController = TextEditingController();
  final List<_LineItem> _items = [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initDefaults);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initDefaults() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    final (wh, _) = await ref.read(ensureDefaultWarehouseUseCaseProvider).call(branch.id);
    if (mounted) setState(() => _fromWarehouseId = wh?.id);
  }

  Future<void> _save() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    if (_toBranchId == null) {
      setState(() => _error = 'Select a destination branch.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final failure = await ref.read(transfersProvider.notifier).create(
          fromBranchId: branch.id,
          toBranchId: _toBranchId!,
          fromWarehouseId: _fromWarehouseId,
          toWarehouseId: _toWarehouseId,
          items: _items.map((i) => {
            'product_id': i.productId,
            'qty': i.qty,
            'cost_price': i.costPrice,
          }).toList(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure is InsufficientStockFailure
            ? 'Insufficient stock at source.'
            : failure.message;
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(onAdd: (item) {
        setState(() => _items.add(item));
        _error = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.read(currentBranchProvider);
    final userBranches = ref.watch(userBranchesProvider).value ?? <Branch>[];
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];
    final destBranches = userBranches.where((b) => b.id != currentBranch?.id).toList();
    final selectedToBranch = userBranches.where((b) => b.id == _toBranchId).firstOrNull;
    final selectedFromWh = warehouses.where((w) => w.id == _fromWarehouseId).firstOrNull;
    final selectedToWh = warehouses.where((w) => w.id == _toWarehouseId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Transfer', style: AppTypography.headline),
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
              _BranchPicker(
                branches: destBranches,
                selected: selectedToBranch,
                label: 'Destination Branch',
                icon: Icons.business,
                emptyLabel: 'No other branches available',
                onChanged: (b) => setState(() { _toBranchId = b?.id; _error = null; }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              _WarehousePicker(
                warehouses: warehouses,
                selected: selectedFromWh,
                label: 'Source Warehouse (optional)',
                onChanged: (w) => setState(() { _fromWarehouseId = w?.id; _error = null; }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              _WarehousePicker(
                warehouses: warehouses,
                selected: selectedToWh,
                label: 'Destination Warehouse (optional)',
                onChanged: (w) => setState(() { _toWarehouseId = w?.id; _error = null; }),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              AppTextField(
                controller: _notesController,
                label: 'Notes',
                prefixIcon: Icons.edit_note,
                hint: 'Optional',
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Text('Line Items', style: AppTypography.subhead),
                  const Spacer(),
                  AppButton(label: 'Add Item', onPressed: _addItem, variant: AppButtonVariant.tinted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text('No items added.', style: AppTypography.footnote.copyWith(color: AppColors.textHint), textAlign: TextAlign.center),
                )
              else
                ..._items.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LineItemCard(
                    index: e.key,
                    item: e.value,
                    onRemove: () => setState(() => _items.removeAt(e.key)),
                  ),
                )),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Create Transfer',
                loading: _saving,
                onPressed: _save,
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

class _LineItem {
  final String productId;
  final String productName;
  final double qty;
  final double costPrice;
  const _LineItem({required this.productId, required this.productName, required this.qty, required this.costPrice});
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.index, required this.item, required this.onRemove});
  final int index;
  final _LineItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            radius: 16,
            child: Text('${index + 1}', style: AppTypography.caption.copyWith(color: AppColors.accent)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${item.qty} × ${item.costPrice.toStringAsFixed(2)}', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.destructive), onPressed: onRemove),
        ],
      ),
    );
  }
}

class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog({required this.onAdd});
  final void Function(_LineItem) onAdd;

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  String? _productId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController(text: '0');

  @override
  void dispose() { _qtyCtrl.dispose(); _costCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    // SERVICE products are non-stock — exclude from the transfer picker.
    final active =
        products.where((p) => p.isActive && p.type != ProductType.service).toList();
    final selectedProduct = active.where((p) => p.id == _productId).firstOrNull;

    return AlertDialog(
      title: const Text('Add Line Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showProductPicker(context, active),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(selectedProduct?.name ?? 'Select product', style: selectedProduct != null ? AppTypography.body : AppTypography.fieldHint)),
                  Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(controller: _qtyCtrl, label: 'Quantity', prefixIcon: Icons.numbers, keyboardType: TextInputType.number, hint: '1'),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(controller: _costCtrl, label: 'Cost per Unit', prefixIcon: Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true), hint: '0'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final qty = double.tryParse(_qtyCtrl.text) ?? 0;
          if (_productId == null || qty <= 0) return;
          widget.onAdd(_LineItem(
            productId: _productId!,
            productName: selectedProduct?.name ?? '',
            qty: qty,
            costPrice: double.tryParse(_costCtrl.text) ?? 0,
          ));
          Navigator.pop(context);
        }, child: const Text('Add')),
      ],
    );
  }

  void _showProductPicker(BuildContext context, List<Product> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 5, decoration: BoxDecoration(color: AppColors.separator, borderRadius: BorderRadius.circular(2.5))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding), child: Text('Select Product', style: AppTypography.subhead)),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.accent.withValues(alpha: 0.1), child: Text(p.name[0].toUpperCase(), style: AppTypography.body.copyWith(color: AppColors.accent))),
                    title: Text(p.name, style: AppTypography.body),
                    subtitle: Text('SKU: ${p.sku}', style: AppTypography.caption),
                    onTap: () { setState(() => _productId = p.id); Navigator.pop(ctx); },
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

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.branches, required this.selected, required this.label, required this.icon, required this.emptyLabel, this.onChanged});
  final List<Branch> branches;
  final Branch? selected;
  final String label, emptyLabel;
  final IconData icon;
  final ValueChanged<Branch?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: AppTypography.fieldLabel)),
        InkWell(
          onTap: branches.isEmpty ? null : () => _showPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(icon, size: 20, color: branches.isEmpty ? AppColors.textHint : AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  selected?.name ?? (branches.isEmpty ? emptyLabel : 'Select branch'),
                  style: selected != null ? AppTypography.body : AppTypography.fieldHint,
                )),
                if (branches.isNotEmpty) Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
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
          children: branches.map((b) => ListTile(
            leading: Icon(icon, size: 20),
            title: Text(b.name),
            subtitle: Text(b.code, style: AppTypography.caption),
            onTap: () { Navigator.pop(ctx); onChanged?.call(b); },
          )).toList(),
        ),
      ),
    );
  }
}

class _WarehousePicker extends StatelessWidget {
  const _WarehousePicker({required this.warehouses, required this.selected, required this.label, required this.onChanged});
  final List<Warehouse> warehouses;
  final Warehouse? selected;
  final String label;
  final ValueChanged<Warehouse?> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = warehouses.where((w) => w.isActive).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: AppTypography.fieldLabel)),
        InkWell(
          onTap: () => _showPicker(context, active),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.warehouse, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(selected?.name ?? 'None (branch default)', style: selected != null ? AppTypography.body : AppTypography.fieldHint)),
                Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context, List<Warehouse> active) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.business, size: 20), title: const Text('None (branch default)'), onTap: () { Navigator.pop(ctx); onChanged(null); }),
            ...active.map((w) => ListTile(
              leading: const Icon(Icons.warehouse, size: 20),
              title: Text(w.name),
              subtitle: Text(w.code, style: AppTypography.caption),
              trailing: w.isDefault ? const Icon(Icons.star, size: 16, color: AppColors.accent) : null,
              onTap: () { Navigator.pop(ctx); onChanged(w); },
            )),
          ],
        ),
      ),
    );
  }
}
