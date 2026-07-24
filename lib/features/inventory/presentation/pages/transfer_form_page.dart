import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
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

    showAppToast(context, 'Transfer created');
    Navigator.of(context).pop();
  }

  Future<void> _addItem() async {
    final item = await showAppSheet<_LineItem>(
      context: context,
      builder: (_) => const _AddItemSheet(),
    );
    if (item == null || !mounted) return;
    setState(() {
      _items.add(item);
      _error = null;
    });
  }

  Future<void> _pickBranch(List<Branch> branches) async {
    if (branches.isEmpty) return;
    await showAppSheet<void>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'Destination branch',
        rows: [
          for (final b in branches)
            _PickerRow(
              icon: LucideIcons.building2,
              title: b.name,
              subtitle: b.code,
              selected: b.id == _toBranchId,
              onTap: () => setState(() { _toBranchId = b.id; _error = null; }),
            ),
        ],
      ),
    );
  }

  Future<void> _pickWarehouse(
    List<Warehouse> warehouses, {
    required bool isSource,
  }) async {
    final active = warehouses.where((w) => w.isActive).toList();
    final selectedId = isSource ? _fromWarehouseId : _toWarehouseId;
    void select(String? id) => setState(() {
          if (isSource) {
            _fromWarehouseId = id;
          } else {
            _toWarehouseId = id;
          }
          _error = null;
        });
    await showAppSheet<void>(
      context: context,
      builder: (_) => _PickerSheet(
        title: isSource ? 'Source warehouse' : 'Destination warehouse',
        rows: [
          _PickerRow(
            icon: LucideIcons.building2,
            title: 'None (branch default)',
            selected: selectedId == null,
            onTap: () => select(null),
          ),
          for (final w in active)
            _PickerRow(
              icon: LucideIcons.warehouse,
              title: w.name,
              subtitle: w.code,
              selected: w.id == selectedId,
              onTap: () => select(w.id),
            ),
        ],
      ),
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

    final canCreate = _toBranchId != null && _items.isNotEmpty;

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'New transfer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionCard(
            eyebrow: 'Transfer details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerField(
                  label: 'Destination branch',
                  icon: LucideIcons.building2,
                  value: selectedToBranch?.name ??
                      (destBranches.isEmpty
                          ? 'No other branches available'
                          : 'Select branch'),
                  placeholder: selectedToBranch == null,
                  onTap: destBranches.isEmpty
                      ? null
                      : () => _pickBranch(destBranches),
                ),
                const SizedBox(height: 14),
                _PickerField(
                  label: 'Source warehouse (optional)',
                  icon: LucideIcons.warehouse,
                  value: selectedFromWh?.name ?? 'None (branch default)',
                  placeholder: selectedFromWh == null,
                  onTap: () => _pickWarehouse(warehouses, isSource: true),
                ),
                const SizedBox(height: 14),
                _PickerField(
                  label: 'Destination warehouse (optional)',
                  icon: LucideIcons.warehouse,
                  value: selectedToWh?.name ?? 'None (branch default)',
                  placeholder: selectedToWh == null,
                  onTap: () => _pickWarehouse(warehouses, isSource: false),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes',
                  prefixIcon: LucideIcons.messageSquare,
                  hint: 'Optional',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSectionCard(
            eyebrow: 'Line items',
            trailing: AppButton(
              label: 'Add item',
              variant: AppButtonVariant.tinted,
              size: AppButtonSize.sm,
              icon: LucideIcons.plus,
              onPressed: _addItem,
            ),
            child: _items.isEmpty
                ? _EmptyItems()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in _items.asMap().entries) ...[
                        _LineItemCard(
                          item: entry.value,
                          onRemove: () =>
                              setState(() => _items.removeAt(entry.key)),
                        ),
                        if (entry.key != _items.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Create transfer',
            loading: _saving,
            fullWidth: true,
            onPressed: canCreate ? _save : null,
          ),
        ],
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

class _EmptyItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'No items yet.',
        textAlign: TextAlign.center,
        style: AppTypography.footnote.copyWith(color: lum.g500),
      ),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.item, required this.onRemove});
  final _LineItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final qty = item.qty == item.qty.roundToDouble()
        ? item.qty.toInt().toString()
        : item.qty.toStringAsFixed(2);
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 38,
            height: 38,
            child: Center(
              child: Icon(LucideIcons.package, size: 18, color: lum.accentPress),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qty × ${item.costPrice.toStringAsFixed(2)}',
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Remove item',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(LucideIcons.x, size: 18, color: lum.g500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet/dialog to build one transfer line: pick a product, enter a
/// quantity and cost per unit. Pops the assembled [_LineItem] on Add.
class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  String? _productId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController(text: '0');

  @override
  void dispose() { _qtyCtrl.dispose(); _costCtrl.dispose(); super.dispose(); }

  void _add(List<Product> active) {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (_productId == null || qty <= 0) return;
    final selectedProduct = active.where((p) => p.id == _productId).firstOrNull;
    Navigator.of(context).pop(_LineItem(
      productId: _productId!,
      productName: selectedProduct?.name ?? '',
      qty: qty,
      costPrice: double.tryParse(_costCtrl.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    // SERVICE products are non-stock — exclude from the transfer picker.
    final active =
        products.where((p) => p.isActive && p.type != ProductType.service).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: 'Add line item'),
        _Labeled(
          label: 'Product',
          child: AppDropdown<String>(
            value: _productId,
            placeholder: 'Select product',
            options: [
              for (final p in active)
                AppDropdownOption(value: p.id, label: p.name),
            ],
            onSelected: (id) => setState(() => _productId = id),
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _qtyCtrl,
          label: 'Quantity',
          prefixIcon: LucideIcons.hash,
          keyboardType: TextInputType.number,
          hint: '1',
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _costCtrl,
          label: 'Cost per unit',
          prefixIcon: LucideIcons.dollarSign,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: '0',
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Add item',
          icon: LucideIcons.plus,
          fullWidth: true,
          onPressed: () => _add(active),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.plain,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A labelled, tappable clay well used for the branch and warehouse pickers.
/// When [onTap] is null the well renders non-interactive.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label,
              style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        Semantics(
          button: true,
          label: '$label: $value',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.7 : 1,
              child: ClayContainer(
                variant: ClayVariant.inset,
                color: lum.surface2,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: lum.g400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.fieldText.copyWith(
                          color:
                              placeholder ? lum.textTertiary : lum.textPrimary,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label,
              style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        child,
      ],
    );
  }
}

/// One selectable row inside a [_PickerSheet].
class _PickerRow {
  const _PickerRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
}

/// A bottom-sheet/dialog listing selectable rows. Tapping a row closes the sheet
/// and fires its callback, so the caller owns the state mutation.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.rows});

  final String title;
  final List<_PickerRow> rows;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: title),
        for (final row in rows) ...[
          Semantics(
            button: true,
            selected: row.selected,
            label: row.title,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  row.onTap();
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ClayContainer(
                  variant: ClayVariant.inset,
                  color: row.selected ? lum.accentSoft : lum.surface2,
                  borderRadius: AppRadius.md,
                  isDark: lum.isDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(row.icon,
                          size: 18,
                          color: row.selected ? lum.accentPress : lum.g500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subhead.copyWith(
                                color: lum.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (row.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                row.subtitle!,
                                style: AppTypography.caption
                                    .copyWith(color: lum.g500),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (row.selected)
                        Icon(LucideIcons.check,
                            size: 18, color: lum.accentPress),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
