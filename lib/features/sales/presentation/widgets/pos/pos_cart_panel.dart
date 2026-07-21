import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_radius.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/design/clay.dart';
import '../../../../../core/design/format.dart';
import '../../../../../core/design/widgets/app_button.dart';
import '../../../../../core/design/widgets/app_money_text.dart';
import '../../../../../core/design/widgets/app_qty_stepper.dart';
import '../../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../../core/design/widgets/app_toast.dart';
import '../../../../customers/presentation/controllers/customers_controller.dart';
import '../../../domain/entities/cart_line.dart';
import '../../controllers/pos_cart_controller.dart';
import '../sales_empty_state.dart';

/// The design's cart column: customer, lines, then the totals footer.
class PosCartPanel extends ConsumerWidget {
  const PosCartPanel({
    super.key,
    required this.cart,
    required this.branchId,
    required this.sessionId,
    required this.onPickCustomer,
    required this.heldCount,
    required this.onOpenHeld,
  });

  final CartState cart;
  final String branchId;
  final String? sessionId;
  final VoidCallback onPickCustomer;
  final int heldCount;
  final VoidCallback onOpenHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;

    return Container(
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(left: BorderSide(color: lum.hairline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: PosCustomerButton(
              customer: cart.customer,
              onTap: onPickCustomer,
            ),
          ),
          Expanded(
            child: cart.lines.isEmpty
                ? const SalesEmptyState(
                    icon: LucideIcons.shoppingCart,
                    message: 'Tap a part to start the sale.\n'
                        'Nothing added yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: cart.lines.length,
                    itemBuilder: (context, i) => PosCartLineRow(
                      line: cart.lines[i],
                      onRemove: () => ref
                          .read(posCartProvider.notifier)
                          .removeLine(cart.lines[i].id),
                      onQtyChanged: (q) => ref
                          .read(posCartProvider.notifier)
                          .updateQty(cart.lines[i].id, q.toDouble()),
                    ),
                  ),
          ),
          PosCartFooter(
            cart: cart,
            branchId: branchId,
            sessionId: sessionId,
            heldCount: heldCount,
            onOpenHeld: onOpenHeld,
          ),
        ],
      ),
    );
  }
}

/// Inset row naming the customer this sale is billed to.
class PosCustomerButton extends ConsumerWidget {
  const PosCustomerButton({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final dynamic customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final isWalkIn = customer == null;
    final name = isWalkIn ? 'Walk-in customer' : '${customer.name}';
    final creditLimit =
        isWalkIn ? 0.0 : (customer.creditLimit as double? ?? 0.0);

    // Remaining credit = limit − outstanding (guard basis). Best-effort: only
    // shown when a limit is set and the ledger resolves; never blocks the sale.
    String? meta;
    if (!isWalkIn && creditLimit > 0) {
      final outstanding =
          ref.watch(customerOutstandingProvider(customer.id as String)).value;
      if (outstanding != null) {
        meta = 'Credit left ${formatPkr(creditLimit - outstanding)}';
      }
    }

    return Semantics(
      button: true,
      label: 'Customer: $name',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ClayContainer(
          variant: ClayVariant.inset,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: lum.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.user, size: 18, color: lum.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: isWalkIn ? lum.textPrimary : lum.accentPress,
                      ),
                    ),
                    if (meta != null)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11.5,
                          color: lum.g500,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cart line: name, unit maths, stepper, line total and remove.
class PosCartLineRow extends StatelessWidget {
  const PosCartLineRow({
    super.key,
    required this.line,
    required this.onRemove,
    required this.onQtyChanged,
  });

  final CartLine line;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 13.5,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPkr(line.unitPrice)} × ${line.qty.toStringAsFixed(0)}',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11.5,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppQtyStepper(
            value: line.qty.round(),
            onChanged: onQtyChanged,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Align(
              alignment: Alignment.centerRight,
              child: AppMoneyText(line.lineTotal, size: 13.5),
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove ${line.productName}',
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(LucideIcons.x, size: 16, color: lum.g400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Totals plus the hold / charge actions.
class PosCartFooter extends ConsumerWidget {
  const PosCartFooter({
    super.key,
    required this.cart,
    required this.branchId,
    required this.sessionId,
    required this.heldCount,
    required this.onOpenHeld,
  });

  final CartState cart;
  final String branchId;
  final String? sessionId;
  final int heldCount;
  final VoidCallback onOpenHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final empty = cart.lines.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FooterLine(
            label: 'Subtotal · ${cart.totalItems} items',
            value: cart.subtotal,
          ),
          if (cart.discountTotal > 0)
            _FooterLine(label: 'Discount', value: -cart.discountTotal),
          if (cart.taxTotal > 0)
            _FooterLine(label: 'Tax', value: cart.taxTotal),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTypography.label.copyWith(color: lum.textPrimary),
                ),
              ),
              AppMoneyText(cart.grandTotal, size: 27),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Held · $heldCount',
                  onPressed: onOpenHeld,
                  variant: AppButtonVariant.plain,
                  icon: LucideIcons.list,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Hold',
                  onPressed: empty ? null : () => _hold(context, ref),
                  variant: AppButtonVariant.plain,
                  icon: LucideIcons.pause,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Charge ${formatPkr(cart.grandTotal)}',
            onPressed: empty
                ? null
                : () => context.push(
                      '/sales/payment',
                      extra: {'branchId': branchId, 'sessionId': sessionId},
                    ),
            fullWidth: true,
            icon: LucideIcons.creditCard,
          ),
        ],
      ),
    );
  }

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final label = await showHoldLabelDialog(context, cart.customer?.name);
    if (label == null || !context.mounted) return;
    final ok = await ref.read(posCartProvider.notifier).hold(
          branchId: branchId,
          sessionId: sessionId,
          label: label,
        );
    if (ok && context.mounted) {
      showAppToast(context, 'Sale held · $label', type: BannerType.success);
    }
  }
}

/// Asks for the label a held sale is filed under, pre-filled the way the design
/// does (customer name, else the time of day).
Future<String?> showHoldLabelDialog(
  BuildContext context,
  String? customerName,
) {
  final now = TimeOfDay.now();
  final fallback = 'Counter '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
  final controller = TextEditingController(text: customerName ?? fallback);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final lum = dialogContext.lum;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClayContainer(
          variant: ClayVariant.raised,
          color: lum.surface,
          borderRadius: AppRadius.xl,
          isDark: lum.isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hold this sale', style: AppTypography.title3),
              const SizedBox(height: 6),
              Text(
                'Give it a label so you can find it again.',
                style: AppTypography.footnote.copyWith(color: lum.g500),
              ),
              const SizedBox(height: 18),
              ClayContainer(
                variant: ClayVariant.inset,
                color: lum.surface2,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: AppTypography.fieldText.copyWith(
                      color: lum.textPrimary,
                    ),
                    cursorColor: lum.accent,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (value) =>
                        Navigator.pop(dialogContext, _clean(value, fallback)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: 'Hold sale',
                fullWidth: true,
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _clean(controller.text, fallback),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Cancel',
                fullWidth: true,
                variant: AppButtonVariant.plain,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _clean(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();

class _FooterLine extends StatelessWidget {
  const _FooterLine({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.footnote.copyWith(
                fontSize: 13.5,
                color: lum.g500,
              ),
            ),
          ),
          AppMoneyText(value, size: 13, color: lum.g600),
        ],
      ),
    );
  }
}
