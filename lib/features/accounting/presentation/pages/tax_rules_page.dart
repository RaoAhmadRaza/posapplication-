import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/tax_rule.dart';
import '../controllers/tax_rules_controller.dart';
import '../widgets/accounting_ui.dart';

class TaxRulesPage extends ConsumerWidget {
  const TaxRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taxRulesProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Tax rules',
      actions: [
        PermissionGate(
          module: 'accounting',
          action: 'create',
          child: AppButton(
            label: 'New rule',
            size: AppButtonSize.sm,
            icon: LucideIcons.plus,
            onPressed: () => context.push('/accounting/tax-rules/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppErrorState(
          title: "Couldn't load tax rules",
          body: 'Your data is safe. Check the connection and try again.',
          onRetry: () => ref.read(taxRulesProvider.notifier).refresh(),
        ),
        data: (rules) => rules.isEmpty
            ? const AppEmptyState(
                icon: LucideIcons.percent,
                title: 'No tax rules yet',
                body: 'Create a rule to apply tax automatically.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rules.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i < rules.length - 1 ? 12 : 0),
                      child: _TaxCard(rule: rules[i]),
                    ),
                ],
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
    final lum = context.lum;
    final isInclusive = rule.mode == TaxMode.inclusive;
    return AppCard(
      onTap: () => context.push('/accounting/tax-rules/${rule.id}/edit'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name, style: AppTypography.headline),
                    if (rule.code != null && rule.code!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      AcctMono(
                        rule.code!,
                        color: lum.g500,
                        size: 12,
                        align: TextAlign.left,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AcctMono(
                '${rule.rate == rule.rate.roundToDouble() ? rule.rate.toInt() : rule.rate}%',
                color: lum.accentPress,
                size: 20,
                weight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppPill(
                label: isInclusive ? 'Inclusive' : 'Exclusive',
                tone: isInclusive ? AppPillTone.warning : AppPillTone.neutral,
              ),
              if (rule.isDefault)
                const AppPill(label: 'Default', tone: AppPillTone.lumen),
              if (rule.appliesTo != null && rule.appliesTo!.isNotEmpty)
                Text(
                  'Applies to ${rule.appliesTo}',
                  style: AppTypography.subhead.copyWith(color: lum.g500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
