import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/search_products.dart';

/// Bottom-sheet product picker returning the chosen [Product] to add as a part.
Future<Product?> showRepairProductPicker(BuildContext context) {
  return showModalBottomSheet<Product?>(
    context: context,
    isScrollControlled: true,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Select Part', style: AppTypography.title2),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchCtrl,
              label: 'Search products',
              prefixIcon: Icons.search,
              hint: 'Name, SKU or barcode',
              onSubmitted: _search,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(_error!,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.destructive)),
              )
            else
              Flexible(
                child: _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text('Search to add a part.',
                            style: AppTypography.footnote
                                .copyWith(color: AppColors.textMuted)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.inventory_2_outlined,
                                color: AppColors.textMuted),
                            title:
                                Text(p.name, style: AppTypography.headline),
                            subtitle: Text(p.sku,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted)),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card)),
                            onTap: () => Navigator.of(context).pop(p),
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
