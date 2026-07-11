import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/failures/sales_failure.dart';
import '../controllers/session_controller.dart';

class CloseSessionPage extends ConsumerStatefulWidget {
  const CloseSessionPage({super.key});

  @override
  ConsumerState<CloseSessionPage> createState() => _CloseSessionPageState();
}

class _CloseSessionPageState extends ConsumerState<CloseSessionPage> {
  final _closingCtrl = TextEditingController();
  bool _loading = false;
  SalesFailure? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _closingCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    final closingFloat = double.tryParse(_closingCtrl.text) ?? 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(sessionProvider.notifier).close(
          sessionId: session.id,
          closingFloat: closingFloat,
        );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = SessionNotOpenFailure();
      });
    } else {
      setState(() {
        _loading = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'sales',
      action: 'create',
      fallback: const NoAccessScaffold(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);

    if (sessionState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = sessionState.value;

    if (_result != null) {
      final expected = double.tryParse(_result!['expected_float']?.toString() ?? '0') ?? 0;
      final closing = double.tryParse(_result!['closing_float']?.toString() ?? '0') ?? 0;
      final variance = double.tryParse(_result!['cash_variance']?.toString() ?? '0') ?? 0;
      final sales = double.tryParse(_result!['total_sales']?.toString() ?? '0') ?? 0;
      final txns = _result!['total_transactions'] as int? ?? 0;

      String varianceLabel;
      Color varianceColor;
      if (variance == 0) {
        varianceLabel = 'Balanced';
        varianceColor = AppColors.success;
      } else if (variance > 0) {
        varianceLabel = 'Over by ${formatPkr(variance)}';
        varianceColor = AppColors.success;
      } else {
        varianceLabel = 'Short by ${formatPkr(-variance)}';
        varianceColor = AppColors.destructive;
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Close Session', style: AppTypography.headline),
        ),
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
                    color: varianceColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    variance == 0 ? Icons.check_circle : Icons.info_outline,
                    size: 36,
                    color: varianceColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Session Closed', style: AppTypography.title2),
                const SizedBox(height: AppSpacing.md),
                _SummaryRow(label: 'Total Sales', value: sales),
                _SummaryRow(label: 'Transactions', value: txns.toDouble()),
                _SummaryRow(label: 'Expected Float', value: expected),
                _SummaryRow(label: 'Closing Float', value: closing),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.base),
                  decoration: BoxDecoration(
                    color: varianceColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    varianceLabel,
                    style: AppTypography.headline.copyWith(color: varianceColor),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Go to POS',
                  onPressed: () => context.go('/sales'),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Close Session', style: AppTypography.headline),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No open session.', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Go to Sales',
                onPressed: () => context.go('/sales'),
                variant: AppButtonVariant.plain,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Close Session', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              _SummaryRow(label: 'Total Sales', value: session.totalSales),
              _SummaryRow(label: 'Transactions', value: session.totalTransactions.toDouble()),
              _SummaryRow(label: 'Opening Float', value: session.openingFloat),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _closingCtrl,
                label: 'Closing Float (Counted Cash)',
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: '0',
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineBanner(message: _error!.message, type: BannerType.error),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Close Session',
                onPressed: _loading ? null : _close,
                loading: _loading,
                fullWidth: true,
                variant: AppButtonVariant.destructive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
          Text(
            formatPkr(value),
            style: AppTypography.headline,
          ),
        ],
      ),
    );
  }
}
