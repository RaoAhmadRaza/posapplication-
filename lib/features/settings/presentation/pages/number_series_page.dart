import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/number_series_info.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/number_series_controller.dart';

class NumberSeriesPage extends ConsumerWidget {
  const NumberSeriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(numberSeriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Number series', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: e is SettingsFailure ? e.message : e.toString(),
            ),
          ),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => _SeriesCard(info: list[i]),
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.info});

  final NumberSeriesInfo info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.type, style: AppTypography.body),
          const SizedBox(height: AppSpacing.sm),
          Text('Prefix: ${info.prefix}', style: AppTypography.subtitleMuted),
          Text('Padding: ${info.padding}', style: AppTypography.subtitleMuted),
          Text(
            'Next: ${info.nextNumberPreview}',
            style: AppTypography.subtitleMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Tooltip(
            message:
                'Inert: the number format has no year component, so year '
                'reset is not applied.',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fiscal-year reset (inactive)',
                    style: AppTypography.subtitleMuted,
                  ),
                ),
                Switch(value: info.fiscalYearReset, onChanged: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
