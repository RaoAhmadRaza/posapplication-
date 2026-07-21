import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/search_products.dart';
import 'repair_customer_picker.dart';
import 'repair_sheet.dart';

/// Product picker returning the chosen [Product] to add as a part — the
/// design's PickerList in a repair sheet.
Future<Product?> showRepairProductPicker(BuildContext context) {
  return showRepairSheet<Product>(
    context: context,
    builder: (_) => const _RepairProductPicker(),
  );
}

class _RepairProductPicker extends ConsumerStatefulWidget {
  const _RepairProductPicker();

  @override
  ConsumerState<_RepairProductPicker> createState() =>
      _RepairProductPickerState();
}

class _RepairProductPickerState extends ConsumerState<_RepairProductPicker> {
  final _searchCtrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (products, failure) =
        await ref.read(searchProductsUseCaseProvider).call(q.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (failure != null) {
        _error = failure.message;
        _results = [];
      } else {
        _results = products;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RepairPickerTitle(title: 'Select part'),
        const SizedBox(height: 14),
        RepairPickerSearch(
          controller: _searchCtrl,
          hint: 'Name, SKU or barcode',
          semanticsLabel: 'Search products',
          onSubmitted: _search,
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          RepairPickerMessage(text: _error!, isError: true)
        else if (_results.isEmpty)
          const RepairPickerMessage(text: 'Search to add a part.')
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: repairPickerListMaxHeight(context),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ProductRow(
                product: _results[i],
                onTap: () => Navigator.of(context).pop(_results[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final qty = product.qtyOnHand;
    // Stock is only shown when the entity actually carries it — the search
    // result may not join stock levels at all.
    final outOfStock = qty != null && qty <= 0;
    final subtitle = qty == null
        ? product.sku
        : '${product.sku} · ${qty.toStringAsFixed(0)} in stock';

    return RepairPickerRow(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lum.g100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(LucideIcons.package, size: 18, color: lum.g500),
      ),
      title: product.name,
      subtitle: subtitle,
      subtitleMono: true,
      dimmed: outOfStock,
      trailing: AppMoneyText(product.sellingPrice, size: 14),
      onTap: onTap,
    );
  }
}
