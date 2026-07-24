import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_qty_stepper.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/entities/product.dart';
import '../../data/services/label_pdf_service.dart';
import '../controllers/barcode_templates_controller.dart';
import '../controllers/products_controller.dart';
import '../widgets/inventory_ui.dart';

class LabelPrintPage extends ConsumerStatefulWidget {
  const LabelPrintPage({super.key, required this.productIds});

  final List<String> productIds;

  @override
  ConsumerState<LabelPrintPage> createState() => _LabelPrintPageState();
}

class _LabelPrintPageState extends ConsumerState<LabelPrintPage> {
  final Map<String, int> _quantities = {};
  String? _templateId;
  bool _generating = false;

  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    final all = ref.read(productsProvider).value ?? <Product>[];
    _products = all.where((p) => widget.productIds.contains(p.id)).toList();
    for (final p in _products) {
      _quantities[p.id] = 1;
    }
    setState(() {});
  }

  List<Product> _expandedProducts() {
    final result = <Product>[];
    for (final p in _products) {
      final qty = _quantities[p.id] ?? 1;
      for (var i = 0; i < qty; i++) {
        result.add(p);
      }
    }
    return result;
  }

  /// Mirrors the template resolution in [_print]: honour an explicit pick, else
  /// the tenant default, else the first template.
  BarcodeTemplate? _selectedTemplate(List<BarcodeTemplate> templates) {
    if (templates.isEmpty) return null;
    if (_templateId != null) {
      final match = templates.where((t) => t.id == _templateId).firstOrNull;
      if (match != null) return match;
    }
    return templates.where((t) => t.isDefault).firstOrNull ?? templates.first;
  }

  Future<void> _print() async {
    final templates =
        ref.read(barcodeTemplatesProvider).value ?? <BarcodeTemplate>[];
    if (templates.isEmpty) {
      showAppToast(context, 'No barcode templates found.',
          type: BannerType.error);
      return;
    }

    final template = _templateId != null
        ? templates.where((t) => t.id == _templateId).firstOrNull
        : templates.where((t) => t.isDefault).firstOrNull ?? templates.first;
    if (template == null) {
      showAppToast(context, 'No barcode templates found.',
          type: BannerType.error);
      return;
    }

    final expanded = _expandedProducts();
    if (expanded.isEmpty) {
      showAppToast(context, 'No products selected.', type: BannerType.error);
      return;
    }

    setState(() => _generating = true);

    try {
      final pdf = await LabelPdfService().generate(expanded, template);
      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: 'product-labels.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Failed to generate labels.',
          type: BannerType.error);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final templatesAsync = ref.watch(barcodeTemplatesProvider);
    final templates = templatesAsync.value ?? <BarcodeTemplate>[];
    final selected = _selectedTemplate(templates);
    final labelCount =
        _products.fold<int>(0, (sum, p) => sum + (_quantities[p.id] ?? 1));

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Print labels',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Template',
              style: AppTypography.footnote.copyWith(color: lum.g500)),
          const SizedBox(height: AppSpacing.sm),
          AppDropdown<String>(
            value: selected?.id,
            placeholder: 'Select template',
            options: [
              for (final t in templates)
                AppDropdownOption(
                  value: t.id,
                  label:
                      '${t.name}  ·  ${t.format}  ·  ${t.widthMm}×${t.heightMm}mm',
                ),
            ],
            onSelected: (id) => setState(() => _templateId = id),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'No products selected.',
                  style: AppTypography.subhead.copyWith(color: lum.g500),
                ),
              ),
            )
          else
            for (var i = 0; i < _products.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i < _products.length - 1 ? AppSpacing.md : 0,
                ),
                child: _ProductQtyRow(
                  product: _products[i],
                  quantity: _quantities[_products[i].id] ?? 1,
                  onChanged: (v) =>
                      setState(() => _quantities[_products[i].id] = v),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          ClayContainer(
            variant: ClayVariant.lumen,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.tag, size: 17, color: lum.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    selected != null
                        ? '$labelCount labels · ${selected.name}'
                        : '$labelCount labels',
                    style: AppTypography.footnote.copyWith(color: lum.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Preview & print',
            loading: _generating,
            fullWidth: true,
            onPressed: _generating || _products.isEmpty ? null : _print,
            icon: LucideIcons.printer,
          ),
        ],
      ),
    );
  }
}

class _ProductQtyRow extends StatelessWidget {
  const _ProductQtyRow({
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 42,
            height: 42,
            child: Center(
              child: Icon(kInvItemIcon, size: 19, color: lum.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  product.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 12, color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppQtyStepper(
            value: quantity,
            min: 1,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
