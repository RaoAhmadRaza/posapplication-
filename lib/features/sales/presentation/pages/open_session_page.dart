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
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/failures/sales_failure.dart';
import '../controllers/session_controller.dart';

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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session != null) {
      final openedAt = session.openedAt;
      final timeStr = '${openedAt.day}/${openedAt.month}/${openedAt.year} '
          '${openedAt.hour.toString().padLeft(2, '0')}:${openedAt.minute.toString().padLeft(2, '0')}';
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          title: Text('Open Session', style: AppTypography.headline),
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
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.point_of_sale, size: 36, color: AppColors.accent),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Session Already Open', style: AppTypography.title2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Opened $timeStr · Float ${formatPkr(session.openingFloat)}',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Resume Selling',
                  onPressed: () => context.go('/sales/pos'),
                  fullWidth: true,
                  icon: Icons.shopping_cart,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Close & Reconcile',
                  onPressed: () => context.go('/sales/session/close'),
                  fullWidth: true,
                  variant: AppButtonVariant.tinted,
                  icon: Icons.close,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Open Session', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(Icons.point_of_sale, size: 48, color: AppColors.accent),
              const SizedBox(height: AppSpacing.md),
              Text('Open Cashier Session', style: AppTypography.title2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your opening cash float to start selling.',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _floatCtrl,
                label: 'Opening Float (PKR)',
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
                label: 'Open Session',
                onPressed: _loading ? null : _open,
                loading: _loading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
