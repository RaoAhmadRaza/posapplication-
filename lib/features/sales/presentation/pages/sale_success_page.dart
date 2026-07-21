import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/pos_cart_controller.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

class SaleSuccessPage extends ConsumerWidget {
  const SaleSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final result = ref.watch(posCartProvider).lastResult;
    if (result == null) {
      return const SalesScaffold(
        title: 'Sale complete',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final queued = result.status == 'OFFLINE';

    return SalesScaffold(
      title: queued ? 'Sale queued' : 'Sale complete',
      maxContentWidth: 420,
      padding: const EdgeInsets.all(24),
      child: SalesRise(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: lum.successSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 34,
                    color: lum.successText,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                queued ? 'Sale queued' : 'Sale complete',
                textAlign: TextAlign.center,
                style: AppTypography.title1.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    result.invoiceNumber,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: lum.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(result.status),
                ],
              ),
              if (queued) ...[
                const SizedBox(height: 8),
                Text(
                  'Provisional reference — not an invoice number. It syncs and '
                  'gets its real number when the connection is back.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    height: 1.5,
                    color: lum.g500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total paid',
                            style: AppTypography.body.copyWith(color: lum.g600),
                          ),
                        ),
                        AppMoneyText(result.paidAmount, size: 26),
                      ],
                    ),
                    if (result.changeAmount > 0) ...[
                      const SizedBox(height: 10),
                      _Line(
                        label: 'Change due',
                        value: result.changeAmount,
                        color: lum.warningText,
                      ),
                    ],
                    if (result.balance > 0) ...[
                      const SizedBox(height: 10),
                      _Line(
                        label: 'Balance due',
                        value: result.balance,
                        color: lum.warningText,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _Line(label: 'Invoice total', value: result.grandTotal),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Offline: a device cannot fetch a server invoice (none exists yet) — no
              // server receipt. The provisional local_ref above IS the customer's slip.
              if (!queued) ...[
                AppButton(
                  label: 'Receipt',
                  onPressed: () =>
                      context.push('/sales/receipt', extra: result.invoiceId),
                  fullWidth: true,
                  icon: LucideIcons.receiptText,
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: 'New sale',
                onPressed: () {
                  ref.read(posCartProvider.notifier).clear();
                  context.go('/sales/pos');
                },
                fullWidth: true,
                variant: AppButtonVariant.tinted,
              ),
              if (result.balance > 0) ...[
                const SizedBox(height: 10),
                AppButton(
                  label: 'Record payment later',
                  onPressed: () {
                    ref.read(posCartProvider.notifier).clear();
                    context.go('/sales/pos');
                  },
                  fullWidth: true,
                  variant: AppButtonVariant.plain,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statusPill(String status) {
    final (tone, label) = switch (status.toUpperCase()) {
      'PAID' => (AppPillTone.success, 'Paid'),
      'PARTIALLY_PAID' => (AppPillTone.warning, 'Partially paid'),
      'CONFIRMED' => (AppPillTone.lumen, 'Credit'),
      'OFFLINE' => (AppPillTone.warning, 'Queued'),
      _ => (AppPillTone.neutral, status),
    };
    return AppPill(label: label, tone: tone);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.footnote.copyWith(color: lum.g500),
          ),
        ),
        AppMoneyText(value, size: 14, color: color ?? lum.textPrimary),
      ],
    );
  }
}
