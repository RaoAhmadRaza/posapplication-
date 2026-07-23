import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
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

  bool _isLow(Product p) =>
      p.reorderPoint > 0 && (p.qtyOnHand ?? 0) <= p.reorderPoint;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final low = switch (state) {
      AsyncData(:final value) => value.where(_isLow).toList(),
      _ => const <Product>[],
    };
    // Drop selections no longer in the low list.
    _selected.removeWhere((id) => !low.any((p) => p.id == id));

    final description = switch (state) {
      AsyncData() =>
        '${low.length} ${low.length == 1 ? 'product' : 'products'} '
            'at or below reorder point',
      _ => null,
    };

    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: 'Reorder suggestions',
      description: description,
      child: switch (state) {
        AsyncError() => AppErrorState(
            title: 'Could not load products',
            body: 'Something went wrong. Check your connection and retry.',
            onRetry: () => ref.read(productsProvider.notifier).refresh(),
          ),
        AsyncData() when low.isEmpty => const AppEmptyState(
            icon: LucideIcons.checkCheck,
            title: 'All stock above reorder point',
            body: 'Nothing needs restocking right now.',
          ),
        AsyncData() => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in low) ...[
                _ProductRow(
                  product: p,
                  selected: _selected.contains(p.id),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selected.add(p.id);
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              AppButton(
                label: _selected.isEmpty
                    ? 'Select items to reorder'
                    : 'Create PO with ${_selected.length} '
                        'item${_selected.length == 1 ? '' : 's'}',
                icon: LucideIcons.plus,
                fullWidth: true,
                onPressed: _selected.isEmpty ? null : () => _createPo(low),
              ),
            ],
          ),
        _ => const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
      },
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final onHand = (product.qtyOnHand ?? 0);
    final reorder = product.reorderPoint;
    final critical = onHand <= reorder / 2;
    // Honest, transparent figure: units needed to reach the reorder point.
    final below = (reorder - onHand).clamp(0, double.infinity);

    return AppCard(
      onTap: () => onChanged(!selected),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AppCheckbox(value: selected, onChanged: onChanged),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU ${product.sku}',
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.mono,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                onHand.toStringAsFixed(0),
                style: AppTypography.monoValue.copyWith(
                  fontSize: 17,
                  color: critical ? lum.dangerText : lum.warningText,
                ),
              ),
              Text(
                'in stock',
                style: AppTypography.caption.copyWith(color: lum.g400),
              ),
              const SizedBox(height: 6),
              AppPill(
                label: 'Reorder ${reorder.toStringAsFixed(0)}',
                tone: critical ? AppPillTone.danger : AppPillTone.warning,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${below.toStringAsFixed(0)}',
                style: AppTypography.monoValue.copyWith(
                  fontSize: 17,
                  color: lum.accent,
                ),
              ),
              Text(
                'to reorder',
                style: AppTypography.caption.copyWith(color: lum.g400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
