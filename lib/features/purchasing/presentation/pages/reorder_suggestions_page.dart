import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';

typedef ReorderLine = ({String productId, String name, double unitCost});

class ReorderSuggestionsPage extends ConsumerStatefulWidget {
  const ReorderSuggestionsPage({super.key});

  @override
  ConsumerState<ReorderSuggestionsPage> createState() =>
      _ReorderSuggestionsPageState();
}

class _ReorderSuggestionsPageState
    extends ConsumerState<ReorderSuggestionsPage> {
  final _selected = <String>{};

  bool _isLow(Product p) => p.reorderPoint > 0 && (p.qtyOnHand ?? 0) <= p.reorderPoint;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Reorder Suggestions', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.read(productsProvider.notifier).refresh(),
          ),
          data: (products) {
            final low = products.where(_isLow).toList();
            if (low.isEmpty) return const _EmptyState();
            // Drop selections no longer in the low list.
            _selected.removeWhere((id) => !low.any((p) => p.id == id));
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                        vertical: AppSpacing.md),
                    itemCount: low.length,
                    itemBuilder: (_, i) {
                      final p = low[i];
                      return _ProductRow(
                        product: p,
                        selected: _selected.contains(p.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
                _BottomBar(
                  count: _selected.length,
                  onCreate: _selected.isEmpty
                      ? null
                      : () => _createPo(low),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _createPo(List<Product> low) {
    final lines = <ReorderLine>[
      for (final p in low)
        if (_selected.contains(p.id))
          (productId: p.id, name: p.name, unitCost: p.costPrice),
    ];
    context.push('/purchasing/orders/create', extra: lines);
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.selected,
    required this.onChanged,
  });
  final Product product;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final onHand = (product.qtyOnHand ?? 0).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: selected ? Border.all(color: AppColors.accent) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            activeColor: AppColors.accent,
            onChanged: onChanged,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTypography.headline),
                const SizedBox(height: 2),
                Text('SKU ${product.sku}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$onHand on hand',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.destructive)),
              Text('reorder at ${product.reorderPoint}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.count, required this.onCreate});
  final int count;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xxl),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
            top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: AppButton(
        label: count == 0
            ? 'Select items to reorder'
            : 'Create PO with $count item${count == 1 ? '' : 's'}',
        onPressed: onCreate,
        fullWidth: true,
        icon: Icons.add_shopping_cart,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 48, color: AppColors.success),
            const SizedBox(height: AppSpacing.md),
            Text('All stock above reorder point',
                textAlign: TextAlign.center,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load products.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
