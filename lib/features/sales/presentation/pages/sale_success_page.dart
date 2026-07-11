import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/pos_cart_controller.dart';

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
    final result = ref.watch(posCartProvider).lastResult;
    if (result == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 36, color: AppColors.success),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Sale Complete', style: AppTypography.title2),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(result.invoiceNumber, style: AppTypography.headline.copyWith(color: AppColors.accent)),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusChip(status: result.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Row(label: 'Grand Total', value: result.grandTotal, bold: true),
              _Row(label: 'Paid', value: result.paidAmount),
              if (result.changeAmount > 0)
                _Row(label: 'Change', value: result.changeAmount, color: AppColors.success),
              if (result.balance > 0)
                _Row(label: 'Balance Due', value: result.balance, color: AppColors.warning),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'Receipt',
                onPressed: () => context.push('/sales/receipt', extra: result.invoiceId),
                fullWidth: true,
                icon: Icons.receipt_long,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'New Sale',
                onPressed: () {
                  ref.read(posCartProvider.notifier).clear();
                  context.go('/sales/pos');
                },
                fullWidth: true,
                variant: AppButtonVariant.tinted,
              ),
              if (result.balance > 0) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Record Payment (Later)',
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.toUpperCase()) {
      'PAID' => (AppColors.success, 'PAID'),
      'PARTIALLY_PAID' => (AppColors.warning, 'PARTIALLY PAID'),
      'CONFIRMED' => (AppColors.accent, 'CREDIT'),
      _ => (AppColors.textMuted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
          Text(
            formatPkr(value),
            style: (bold ? AppTypography.headline : AppTypography.subhead).copyWith(
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
