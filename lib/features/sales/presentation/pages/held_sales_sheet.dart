import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/held_sale.dart';
import '../controllers/pos_cart_controller.dart';

Future<HeldSale?> showHeldSalesSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<HeldSale?>(
    context: context,
    isScrollControlled: true,
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Held Sales', style: AppTypography.title2),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: AppInlineBanner(message: _error!, type: BannerType.error),
              )
            else if (_held.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Text('No held sales.', style: AppTypography.subhead.copyWith(color: AppColors.textHint)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _held.length,
                  itemBuilder: (_, i) {
                    final h = _held[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.label, style: AppTypography.headline),
                                const SizedBox(height: 2),
                                Text(
                                  '${h.itemCount} items · ${_timeAgo(h.createdAt)}',
                                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.textHint),
                            onPressed: () => _delete(h),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
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
