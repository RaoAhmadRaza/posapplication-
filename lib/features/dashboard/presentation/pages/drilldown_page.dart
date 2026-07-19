import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/drilldown.dart';
import '../controllers/drilldown_controller.dart';

class DrilldownPage extends ConsumerWidget {
  const DrilldownPage({super.key, required this.args, required this.title});

  final DrilldownArgs args;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drilldownProvider(args));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text(title, style: AppTypography.title2),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineBanner(
                  message: 'Could not load details.',
                  type: BannerType.error,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(drilldownProvider(args)),
                  variant: AppButtonVariant.plain,
                ),
              ],
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(
                child: Text(
                  'Nothing to show.',
                  style: AppTypography.subhead
                      .copyWith(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              itemCount: rows.length,
              itemBuilder: (context, i) => _DrilldownRowTile(row: rows[i]),
            );
          },
        ),
      ),
    );
  }
}

class _DrilldownRowTile extends StatelessWidget {
  const _DrilldownRowTile({required this.row});
  final DrilldownRow row;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: AppTypography.headline),
                if (row.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            row.trailing,
            style: AppTypography.headline.copyWith(color: AppColors.accent),
          ),
          if (row.deepLink != null)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(Icons.chevron_right, color: AppColors.separator),
            ),
        ],
      ),
    );
    if (row.deepLink == null) return tile;
    return InkWell(
      onTap: () => context.push(row.deepLink!),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: tile,
    );
  }
}
