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
import '../../domain/entities/ai_recommendation.dart';
import '../controllers/reporting_controllers.dart';

class SmartInsightsPage extends ConsumerWidget {
  const SmartInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Smart Insights', style: AppTypography.largeTitle),
      ),
      body: SafeArea(
        child: PermissionGate(
          module: 'reports',
          action: 'read',
          fallback: Center(
            child: Text(
              'No access.',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted),
            ),
          ),
          child: _body(context, ref),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRecommendationsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: AppInlineBanner(
          message: 'Could not load insights.',
          type: BannerType.error,
        ),
      ),
      data: (recs) {
        if (recs.isEmpty) {
          return Center(
            child: Text(
              'No recommendations right now.',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding)
                  .copyWith(top: AppSpacing.xl, bottom: AppSpacing.xxl),
          itemCount: recs.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => _RecommendationCard(rec: recs[i]),
        );
      },
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.rec});

  final AiRecommendation rec;

  Future<void> _act(BuildContext context, WidgetRef ref, bool accept) async {
    final failure = await ref
        .read(pendingRecommendationsProvider.notifier)
        .act(rec.id, accept);
    if (!context.mounted) return;
    if (accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure == null ? 'Accepted' : failure.message)),
      );
    } else if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }
  }

  Future<void> _createPo(BuildContext context, WidgetRef ref) async {
    await ref.read(pendingRecommendationsProvider.notifier).act(rec.id, true);
    if (!context.mounted) return;
    final seed = <({String productId, String name, double unitCost})>[
      (
        productId: rec.entityId,
        name: rec.recommendation['product']?.toString() ?? '',
        unitCost: 0.0,
      ),
    ];
    context.push('/purchasing/orders/create', extra: seed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = rec.recommendation['product']?.toString() ?? rec.entityId;
    final isReorder = rec.recommendationType == 'REORDER';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeChip(label: rec.recommendationType),
              const Spacer(),
              _ConfidenceBadge(score: rec.confidenceScore),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style:
                AppTypography.headline.copyWith(color: AppColors.textPrimary),
          ),
          if (rec.reasoning != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              rec.reasoning!,
              style:
                  AppTypography.footnote.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              if (isReorder) ...[
                AppButton(
                  label: 'Create PO',
                  onPressed: () => _createPo(context, ref),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              AppButton(
                label: 'Accept',
                variant: AppButtonVariant.tinted,
                onPressed: () => _act(context, ref, true),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Dismiss',
                variant: AppButtonVariant.plain,
                onPressed: () => _act(context, ref, false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${(score * 100).toStringAsFixed(0)}%',
      style: AppTypography.footnote.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
