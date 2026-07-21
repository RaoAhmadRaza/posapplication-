import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_radius.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/design/format.dart';
import '../../controllers/pos_cart_controller.dart';
import 'pos_cart_panel.dart';

/// Floating bar over the mobile catalogue that opens the cart sheet.
///
/// Sits on a scrim that fades into the page so the grid stays readable behind
/// it; the bar itself is the only hit target.
class PosViewCartBar extends StatelessWidget {
  const PosViewCartBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lum.paper.withValues(alpha: 0), lum.paper],
            stops: const [0, 0.62],
          ),
        ),
        child: Semantics(
          button: true,
          label: 'View cart, $itemCount items, ${formatPkr(total)}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: lum.accent,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$itemCount',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'View cart',
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    formatPkr(total),
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet version of the cart for narrow layouts.
Future<void> showPosCartSheet(
  BuildContext context, {
  required String branchId,
  required String? sessionId,
  required VoidCallback onPickCustomer,
  required int heldCount,
  required VoidCallback onOpenHeld,
}) {
  final lum = context.lum;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: lum.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _PosCartSheetBody(
        branchId: branchId,
        sessionId: sessionId,
        onPickCustomer: onPickCustomer,
        heldCount: heldCount,
        onOpenHeld: onOpenHeld,
      ),
    ),
  );
}

class _PosCartSheetBody extends ConsumerWidget {
  const _PosCartSheetBody({
    required this.branchId,
    required this.sessionId,
    required this.onPickCustomer,
    required this.heldCount,
    required this.onOpenHeld,
  });

  final String branchId;
  final String? sessionId;
  final VoidCallback onPickCustomer;
  final int heldCount;
  final VoidCallback onOpenHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final cart = ref.watch(posCartProvider);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: lum.g300,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Cart · ${cart.totalItems} items',
                  style: AppTypography.title3,
                ),
              ),
              Semantics(
                button: true,
                label: 'Close cart',
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(LucideIcons.x, size: 20, color: lum.g500),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PosCartPanel(
            cart: cart,
            branchId: branchId,
            sessionId: sessionId,
            onPickCustomer: onPickCustomer,
            heldCount: heldCount,
            onOpenHeld: onOpenHeld,
          ),
        ),
      ],
    );
  }
}
