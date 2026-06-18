import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/entities/product.dart';
import '../../data/services/label_pdf_service.dart';
import '../controllers/barcode_templates_controller.dart';
import '../controllers/products_controller.dart';

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
  String? _error;

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

  Future<void> _print() async {
    final templates =
        ref.read(barcodeTemplatesProvider).value ?? <BarcodeTemplate>[];
    if (templates.isEmpty) {
      setState(() => _error = 'No barcode templates found.');
      return;
    }

    final template = _templateId != null
        ? templates.where((t) => t.id == _templateId).firstOrNull
        : templates.where((t) => t.isDefault).firstOrNull ??
            templates.first;
    if (template == null) {
      setState(() => _error = 'No barcode templates found.');
      return;
    }

    final expanded = _expandedProducts();
    if (expanded.isEmpty) {
      setState(() => _error = 'No products selected.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final pdf = await LabelPdfService().generate(expanded, template);
      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: 'product-labels.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to generate labels.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(barcodeTemplatesProvider);
    final templates = templatesAsync.value ?? <BarcodeTemplate>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Print Labels', style: AppTypography.headline),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
              child: AppInlineBanner(message: _error!, type: BannerType.error),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text('Template', style: AppTypography.fieldLabel),
                const SizedBox(height: AppSpacing.xs),
                _buildTemplatePicker(templates),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${_products.length} products · ${_expandedProducts().length} labels',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Text(
                      'No products selected.',
                      style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i < _products.length - 1 ? AppSpacing.md : 0,
                      ),
                      child: _ProductQtyRow(
                        product: _products[i],
                        quantity: _quantities[_products[i].id] ?? 1,
                        onChanged: (v) {
                          setState(() => _quantities[_products[i].id] = v);
                        },
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppButton(
                label: 'Preview / Print',
                loading: _generating,
                fullWidth: true,
                onPressed: _generating || _products.isEmpty ? null : _print,
                icon: Icons.print,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePicker(List<BarcodeTemplate> templates) {
    final defaultTemplate =
        templates.where((t) => t.isDefault).firstOrNull ?? templates.firstOrNull;

    final selected = _templateId != null
        ? templates.where((t) => t.id == _templateId).firstOrNull
        : defaultTemplate;

    return InkWell(
      onTap: () => _showTemplatePicker(templates),
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                selected != null
                    ? '${selected.name}  ·  ${selected.format}  ·  ${selected.widthMm}×${selected.heightMm}mm'
                    : 'Select template',
                style: selected != null
                    ? AppTypography.fieldText
                    : AppTypography.fieldHint,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showTemplatePicker(List<BarcodeTemplate> templates) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: templates.map((t) {
            final selected = _templateId == t.id ||
                (_templateId == null && t.isDefault);
            return ListTile(
              leading: const Icon(Icons.qr_code_2, size: 22),
              title: Text(t.name),
              subtitle: Text(
                '${t.format}  ·  ${t.widthMm}×${t.heightMm}mm',
                style: AppTypography.caption,
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () {
                setState(() => _templateId = t.id);
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTypography.callout.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'SKU: ${product.sku}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.separator),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (quantity > 1) onChanged(quantity - 1);
              },
              child: const Icon(Icons.remove, size: 18, color: AppColors.textMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '$quantity',
              style: AppTypography.headline,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.separator),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(quantity + 1),
              child: const Icon(Icons.add, size: 18, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
