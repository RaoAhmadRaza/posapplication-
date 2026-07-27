import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/entities/ai_recommendation.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/reporting_ui.dart';

class SmartInsightsPage extends ConsumerWidget {
  const SmartInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Smart insights',
      description: 'Suggested actions from your recent sales and stock.',
      child: PermissionGate(
        module: 'reports',
        action: 'read',
        fallback: Center(
          child: Text(
            'You don’t have access to reports.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: _body(context, ref),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRecommendationsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: AppErrorState(
          title: 'Unable to load insights',
          body: 'We couldn’t reach the server. Please try again.',
        ),
      ),
      data: (recs) {
        if (recs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.screenPadding),
              child: AppEmptyState(
                icon: LucideIcons.sparkles,
                title: 'No recommendations right now',
                body: 'Suggested actions from your sales and stock will show up '
                    'here as they’re detected.',
              ),
            ),
          );
        }
        return _RecommendationList(recs: recs);
      },
    );
  }
}

/// Shows [_kPageSize] cards at a time; the button reveals the next batch.
/// The provider already holds every pending recommendation, so this is a
/// client-side slice — no extra fetch.
const int _kPageSize = 10;

class _RecommendationList extends StatefulWidget {
  const _RecommendationList({required this.recs});

  final List<AiRecommendation> recs;

  @override
  State<_RecommendationList> createState() => _RecommendationListState();
}

class _RecommendationListState extends State<_RecommendationList> {
  int _visible = _kPageSize;

  @override
  Widget build(BuildContext context) {
    final total = widget.recs.length;
    final shown = _visible.clamp(0, total);
    final remaining = total - shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rec in widget.recs.take(shown)) ...[
          _RecommendationCard(rec: rec),
          const SizedBox(height: AppSpacing.md),
        ],
        if (remaining > 0)
          AppButton(
            label: 'Load more ($remaining left)',
            variant: AppButtonVariant.tinted,
            onPressed: () => setState(() => _visible += _kPageSize),
          ),
      ],
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
      showAppToast(
        context,
        failure == null ? 'Accepted' : failure.message,
        type: failure == null ? BannerType.success : BannerType.error,
      );
    } else if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
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
    final lum = context.lum;
    final title = rec.recommendation['product']?.toString() ?? rec.entityId;
    final isReorder = rec.recommendationType == 'REORDER';
    final conf = (rec.confidenceScore * 100).toStringAsFixed(0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InsightBadge(type: rec.recommendationType),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: confidenceColor(lum, rec.confidenceScore),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$conf% confidence',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: lum.g500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.headline.copyWith(color: lum.textPrimary),
          ),
          if (rec.reasoning != null) ...[
            const SizedBox(height: 6),
            Text(
              rec.reasoning!,
              style: AppTypography.footnote.copyWith(
                color: lum.g600,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isReorder)
                AppButton(
                  label: 'Create PO',
                  size: AppButtonSize.sm,
                  icon: LucideIcons.filePlus,
                  onPressed: () => _createPo(context, ref),
                ),
              AppButton(
                label: 'Accept',
                size: AppButtonSize.sm,
                variant: AppButtonVariant.tinted,
                onPressed: () => _act(context, ref, true),
              ),
              AppButton(
                label: 'Dismiss',
                size: AppButtonSize.sm,
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
