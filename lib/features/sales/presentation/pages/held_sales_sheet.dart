import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/held_sale.dart';
import '../controllers/pos_cart_controller.dart';
import '../widgets/sales_empty_state.dart';

Future<HeldSale?> showHeldSalesSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<HeldSale?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.lum.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _HeldSalesSheet(ref: ref),
  );
}

class _HeldSalesSheet extends ConsumerStatefulWidget {
  const _HeldSalesSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_HeldSalesSheet> createState() => _HeldSalesSheetState();
}

class _HeldSalesSheetState extends ConsumerState<_HeldSalesSheet> {
  List<HeldSale> _held = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(posCartProvider.notifier).loadHeld();
    if (!mounted) return;
    final failure = ref.read(posCartProvider).heldError;
    setState(() {
      _held = list;
      _error = failure?.message;
      _loading = false;
    });
  }

  Future<void> _resume(HeldSale h) async {
    ref.read(posCartProvider.notifier).resume(h);
    await ref.read(posCartProvider.notifier).deleteHeld(h.id);
    if (!mounted) return;
    Navigator.of(context).pop(h);
  }

  Future<void> _delete(HeldSale h) async {
    await ref.read(posCartProvider.notifier).deleteHeld(h.id);
    setState(() => _held.removeWhere((x) => x.id == h.id));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: context.lum.g300,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Held sales', style: AppTypography.title3),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: AppInlineBanner(message: _error!, type: BannerType.error),
              )
            else if (_held.isEmpty)
              const SalesEmptyState(
                icon: LucideIcons.pause,
                message: 'No sales on hold. Park a cart from the POS and it '
                    'will show up here.',
                minHeight: 160,
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _held.length,
                  itemBuilder: (_, i) {
                    final h = _held[i];
                    final lum = context.lum;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: lum.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  h.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: lum.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${h.itemCount} items · ${_timeAgo(h.createdAt)}',
                                  style: AppTypography.monoValue.copyWith(
                                    fontSize: 11.5,
                                    color: lum.g500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Delete ${h.label}',
                            child: InkWell(
                              onTap: () => _delete(h),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  LucideIcons.trash2,
                                  size: 18,
                                  color: lum.g400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AppButton(
                            label: 'Resume',
                            onPressed: () => _resume(h),
                            variant: AppButtonVariant.tinted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
