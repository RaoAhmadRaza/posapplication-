import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/failures/sales_failure.dart';
import '../controllers/session_controller.dart';
import '../controllers/session_sales_provider.dart';
import '../widgets/sales_empty_state.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

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
      return const SalesScaffold(
        title: 'Close session',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final session = sessionState.value;

    if (_result != null) return _closedView(context);

    if (session == null) {
      return SalesScaffold(
        title: 'Close session',
        maxContentWidth: 520,
        padding: const EdgeInsets.all(24),
        child: SalesEmptyState(
          icon: LucideIcons.lock,
          message: 'No register is open right now.',
          action: AppButton(
            label: 'Go to sales',
            onPressed: () => context.go('/sales'),
            variant: AppButtonVariant.plain,
          ),
        ),
      );
    }

    return SalesScaffold(
      title: 'Close session',
      maxContentWidth: 520,
      padding: const EdgeInsets.all(24),
      child: SalesRise(
        duration: const Duration(milliseconds: 350),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionCard(
                eyebrow: 'Session summary',
                child: Consumer(
                  builder: (context, ref, _) {
                    // Live totals: the session row's own total_sales/txns stay 0
                    // until close_cashier_session runs, so read them live here.
                    // Only what close_cashier_session accounts for — no
                    // per-method (cash/card/wallet) split exists in this path.
                    final stats = ref.watch(sessionStatsProvider(session.id));
                    final (sales, txns) = stats.value ?? (0.0, 0);
                    return Column(
                      children: [
                        _SummaryRow(
                            label: 'Opening float', value: session.openingFloat),
                        _SummaryRow(label: 'Total sales', value: sales),
                        _SummaryRow(label: 'Transactions', count: txns),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppMoneyField(
                      controller: _closingCtrl,
                      label: 'Counted cash',
                      onSubmitted: (_) => _loading ? null : _close(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      AppInlineBanner(message: _error!.message),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Close session',
                onPressed: _loading ? null : _close,
                loading: _loading,
                fullWidth: true,
                icon: LucideIcons.lock,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _closedView(BuildContext context) {
    final lum = context.lum;
    final expected =
        double.tryParse(_result!['expected_float']?.toString() ?? '0') ?? 0;
    final closing =
        double.tryParse(_result!['closing_float']?.toString() ?? '0') ?? 0;
    final variance =
        double.tryParse(_result!['cash_variance']?.toString() ?? '0') ?? 0;
    final sales = double.tryParse(_result!['total_sales']?.toString() ?? '0') ?? 0;
    final txns = _result!['total_transactions'] as int? ?? 0;

    final (label, fg, bg) = switch (variance) {
      0 => ('Drawer balanced', lum.successText, lum.successSoft),
      > 0 => ('Over by ${formatPkr(variance)}', lum.accentPress, lum.accentSoft),
      _ => ('Short by ${formatPkr(-variance)}', lum.dangerText, lum.dangerSoft),
    };

    return SalesScaffold(
      title: 'Close session',
      maxContentWidth: 520,
      padding: const EdgeInsets.all(24),
      child: SalesRise(
        duration: const Duration(milliseconds: 350),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionCard(
                eyebrow: 'Session closed',
                child: Column(
                  children: [
                    _SummaryRow(label: 'Total sales', value: sales),
                    _SummaryRow(label: 'Transactions', count: txns),
                    _SummaryRow(label: 'Expected in drawer', value: expected),
                    _SummaryRow(label: 'Counted cash', value: closing),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      variance == 0
                          ? LucideIcons.check
                          : LucideIcons.circleAlert,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.label.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Back to sales',
                onPressed: () => context.go('/sales'),
                fullWidth: true,
                icon: LucideIcons.arrowRight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One label/value line in a summary card. [count] renders a plain integer
/// (transactions are not money), [value] renders the money treatment.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, this.value, this.count});

  final String label;
  final double? value;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(color: lum.g600),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: AppTypography.monoValue.copyWith(
                fontWeight: FontWeight.w600,
                color: lum.textPrimary,
              ),
            )
          else
            AppMoneyText(value ?? 0, size: 15),
        ],
      ),
    );
  }
}
