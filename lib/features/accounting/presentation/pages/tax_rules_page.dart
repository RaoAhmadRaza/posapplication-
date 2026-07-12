import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/tax_rule.dart';
import '../controllers/tax_rules_controller.dart';

class TaxRulesPage extends ConsumerWidget {
  const TaxRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taxRulesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Tax Rules', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'accounting',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/accounting/tax-rules/create'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.read(taxRulesProvider.notifier).refresh(),
          ),
          data: (rules) => rules.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md),
                  itemCount: rules.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(
                        bottom: i < rules.length - 1 ? AppSpacing.md : 0),
                    child: _TaxCard(rule: rules[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TaxCard extends StatelessWidget {
  const _TaxCard({required this.rule});
  final TaxRule rule;

  @override
  Widget build(BuildContext context) {
    final mode = rule.mode == TaxMode.inclusive ? 'Inclusive' : 'Exclusive';
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/accounting/tax-rules/${rule.id}/edit'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(rule.name, style: AppTypography.headline),
                  ),
                  if (rule.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text('Default',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${rule.code ?? '—'} · $mode',
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.textMuted)),
                  Text('${rule.rate.toStringAsFixed(2)}%',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.percent, size: 48, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.md),
          Text('No tax rules',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load tax rules.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
