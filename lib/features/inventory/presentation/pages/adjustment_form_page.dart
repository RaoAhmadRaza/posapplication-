import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/entities/adjustment_reason.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/ensure_default_warehouse.dart';
import '../controllers/adjustments_controller.dart';
import '../controllers/products_controller.dart';
import '../controllers/warehouses_controller.dart';
import '../widgets/inventory_ui.dart';

const _reasons = [
  AdjustmentReason.damage,
  AdjustmentReason.theft,
  AdjustmentReason.expired,
  AdjustmentReason.recount,
  AdjustmentReason.writeOff,
  AdjustmentReason.other,
];

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

  Future<void> _pickProduct(List<Product> products) async {
    final picked = await showAppSheet<Product>(
      context: context,
      builder: (ctx) => _ProductSheet(products: products, selectedId: _selectedProductId),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedProductId = picked.id;
        _error = null;
      });
    }
  }

  Future<void> _pickWarehouse(List<Warehouse> warehouses) async {
    // '' is the sentinel for "None (branch default)"; null means dismissed.
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => _WarehouseSheet(warehouses: warehouses, selectedId: _selectedWarehouseId),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedWarehouseId = picked.isEmpty ? null : picked;
        _error = null;
      });
    }
  }

  void _onReasonChanged(AdjustmentReason r) {
    setState(() {
      _reason = r;
      if (r == AdjustmentReason.writeOff) {
        final current = double.tryParse(_qtyController.text.trim()) ?? 0;
        if (current >= 0) {
          _qtyController.text = current == 0 ? '-1' : '${-current.abs()}';
        }
      }
    });
  }

  bool get _canSubmit {
    if (_selectedProductId == null) return false;
    final qty = double.tryParse(_qtyController.text.trim());
    return qty != null && qty != 0;
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

    showAppToast(
      context,
      adjustment != null && adjustment.requiresApproval
          ? 'Submitted for approval'
          : 'Adjustment posted',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? <Product>[];
    final warehouses = ref.watch(warehousesProvider).value ?? <Warehouse>[];
    // SERVICE products are non-stock — exclude from the adjustment picker.
    final activeProducts =
        products.where((p) => p.isActive && p.type != ProductType.service).toList();
    final selectedProduct = activeProducts.where((p) => p.id == _selectedProductId).firstOrNull;
    final selectedWarehouse = warehouses.where((w) => w.id == _selectedWarehouseId).firstOrNull;

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'New adjustment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          AppSectionCard(
            eyebrow: 'Item',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerField(
                  label: 'Product',
                  icon: kInvItemIcon,
                  value: selectedProduct?.name,
                  placeholder: 'Select a product',
                  onTap: () => _pickProduct(activeProducts),
                ),
                const SizedBox(height: 16),
                _PickerField(
                  label: 'Warehouse',
                  icon: LucideIcons.warehouse,
                  value: selectedWarehouse?.name,
                  placeholder: 'Optional — default branch',
                  onTap: () => _pickWarehouse(warehouses),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSectionCard(
            eyebrow: 'Adjustment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _qtyController,
                  label: 'Quantity',
                  prefixIcon: LucideIcons.arrowUpDown,
                  hint: 'Positive = add, negative = remove',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                AppMoneyField(
                  controller: _costController,
                  label: 'Cost per unit',
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        'Reason',
                        style: AppTypography.fieldLabel.copyWith(color: context.lum.g700),
                      ),
                    ),
                    AppDropdown<AdjustmentReason>(
                      value: _reason,
                      options: [
                        for (final r in _reasons)
                          AppDropdownOption(value: r, label: adjustmentReasonLabel(r)),
                      ],
                      onSelected: _onReasonChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSectionCard(
            eyebrow: 'Notes',
            child: AppTextField(
              controller: _notesController,
              label: 'Notes',
              prefixIcon: LucideIcons.stickyNote,
              hint: 'Optional',
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Create adjustment',
            loading: _posting,
            fullWidth: true,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Labelled tappable well that opens a picker sheet — mirrors the dropdown well
/// so product/warehouse selectors read as one control family.
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
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        Semantics(
          button: true,
          label: '$label: ${hasValue ? value : placeholder}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: lum.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: lum.g400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasValue ? value! : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldText.copyWith(
                        color: hasValue ? lum.textPrimary : lum.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.chevronDown, size: 18, color: lum.g500),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductSheet extends StatelessWidget {
  const _ProductSheet({required this.products, required this.selectedId});

  final List<Product> products;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(title: 'Select product'),
        for (final p in products)
          _SheetOption(
            icon: kInvItemIcon,
            title: p.name,
            subtitle: 'SKU: ${p.sku}',
            selected: p.id == selectedId,
            onTap: () => Navigator.of(context).pop(p),
          ),
      ],
    );
  }
}

class _WarehouseSheet extends StatelessWidget {
  const _WarehouseSheet({required this.warehouses, required this.selectedId});

  final List<Warehouse> warehouses;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(title: 'Select warehouse'),
        _SheetOption(
          icon: LucideIcons.building2,
          title: 'None (branch default)',
          selected: selectedId == null,
          onTap: () => Navigator.of(context).pop(''),
        ),
        for (final w in warehouses.where((w) => w.isActive))
          _SheetOption(
            icon: LucideIcons.warehouse,
            title: w.name,
            subtitle: w.code,
            selected: w.id == selectedId,
            trailing: w.isDefault
                ? Icon(LucideIcons.star, size: 15, color: context.lum.accent)
                : null,
            onTap: () => Navigator.of(context).pop(w.id),
          ),
      ],
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: lum.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: lum.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body.copyWith(color: lum.textPrimary)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTypography.caption.copyWith(color: lum.g500)),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.check, size: 18, color: lum.accent),
            ],
          ],
        ),
      ),
    );
  }
}
