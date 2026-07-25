import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/widgets/no_access_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/cashier_session.dart';
import '../../domain/failures/sales_failure.dart';
import '../controllers/session_controller.dart';
import '../controllers/session_sales_provider.dart';
import '../widgets/sales_rise.dart';
import '../widgets/sales_scaffold.dart';

class OpenSessionPage extends ConsumerStatefulWidget {
  const OpenSessionPage({super.key});

  @override
  ConsumerState<OpenSessionPage> createState() => _OpenSessionPageState();
}

class _OpenSessionPageState extends ConsumerState<OpenSessionPage> {
  final _floatCtrl = TextEditingController(text: '0');
  bool _loading = false;
  SalesFailure? _error;

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    final openingFloat = double.tryParse(_floatCtrl.text) ?? 0;
    if (openingFloat < 0) {
      setState(() => _error = UnknownFailure('Opening float cannot be negative.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final failure = await ref.read(sessionProvider.notifier).open(
          branchId: branch.id,
          openingFloat: openingFloat,
        );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _loading = false;
        _error = failure;
      });
      if (failure is SessionAlreadyOpenFailure) {
        ref.invalidate(sessionProvider);
      }
    } else {
      context.go('/sales/pos');
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
    final session = sessionState.value;

    if (sessionState.isLoading) {
      return const SalesScaffold(
        title: 'Open session',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (session != null) {
      final openedAt = session.openedAt;
      final timeStr = '${openedAt.day}/${openedAt.month}/${openedAt.year} '
          '${openedAt.hour.toString().padLeft(2, '0')}:${openedAt.minute.toString().padLeft(2, '0')}';
      return SalesScaffold(
        title: 'Open session',
        maxContentWidth: 440,
        padding: const EdgeInsets.all(32),
        child: SalesRise(
          child: AppCard(
            raised: true,
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _IconTile(icon: LucideIcons.shoppingCart),
                const SizedBox(height: 20),
                Text(
                  'Register already open',
                  style: AppTypography.title1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Opened $timeStr · float ${formatPkr(session.openingFloat)}. '
                  'Every sale is tracked against this session.',
                  style: AppTypography.footnote.copyWith(
                    height: 1.5,
                    color: context.lum.g500,
                  ),
                ),
                const SizedBox(height: 20),
                _ExpectedCashTile(session: session),
                const SizedBox(height: 6),
                AppButton(
                  label: 'Resume selling',
                  onPressed: () => context.go('/sales/pos'),
                  fullWidth: true,
                  icon: LucideIcons.arrowRight,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Close & reconcile',
                  onPressed: () => context.go('/sales/session/close'),
                  fullWidth: true,
                  variant: AppButtonVariant.tinted,
                  icon: LucideIcons.lock,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SalesScaffold(
      title: 'Open session',
      maxContentWidth: 440,
      padding: const EdgeInsets.all(32),
      child: SalesRise(
        child: AppCard(
          raised: true,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IconTile(icon: LucideIcons.sunrise),
              const SizedBox(height: 20),
              Text(
                'Open register',
                style: AppTypography.title1.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Count the cash in the drawer to start your shift. Every sale '
                'is tracked against this session.',
                style: AppTypography.footnote.copyWith(
                  height: 1.5,
                  color: context.lum.g500,
                ),
              ),
              const SizedBox(height: 22),
              AppMoneyField(
                controller: _floatCtrl,
                label: 'Opening float',
                onSubmitted: (_) => _loading ? null : _open(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AppInlineBanner(message: _error!.message),
              ],
              const SizedBox(height: 22),
              AppButton(
                label: 'Open session',
                onPressed: _loading ? null : _open,
                loading: _loading,
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

/// Live "expected cash in drawer" readout: opening float + cash sales so
/// far this session (same formula close_cashier_session uses to close).
class _ExpectedCashTile extends ConsumerWidget {
  const _ExpectedCashTile({required this.session});
  final CashierSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final expected = ref.watch(
      sessionExpectedCashProvider((session.id, session.openingFloat)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Expected cash in drawer',
              style: AppTypography.footnote.copyWith(color: lum.g600),
            ),
          ),
          expected.when(
            data: (v) => AppMoneyText(v, size: 17),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => Text('—', style: AppTypography.footnote),
          ),
        ],
      ),
    );
  }
}

/// 60px clay tile carrying the screen's glyph, per the design's card header.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.accentSoft,
      borderRadius: AppRadius.clay,
      isDark: lum.isDark,
      width: 60,
      height: 60,
      child: Icon(icon, size: 28, color: lum.accent),
    );
  }
}
