import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/number_series_info.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/number_series_controller.dart';
import '../widgets/settings_note.dart';

class NumberSeriesPage extends ConsumerWidget {
  const NumberSeriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final state = ref.watch(numberSeriesProvider);

    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Number series',
      description: 'How each document type is numbered.',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppInlineBanner(
          message: e is SettingsFailure ? e.message : e.toString(),
        ),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: lum.hairline),
                    _SeriesRow(info: list[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            const SettingsNote(
              'Numbering is view-only here. It is set when your business is '
              'configured, to keep every document sequence audit-safe.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.info});

  final NumberSeriesInfo info;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.type,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                    children: [
                      const TextSpan(text: 'Prefix '),
                      TextSpan(
                        text: info.prefix,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 12.5,
                          color: lum.g700,
                        ),
                      ),
                      TextSpan(text: ' · padded to ${info.padding} digits'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NEXT',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: lum.g400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.nextNumberPreview,
                style: AppTypography.monoValue.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: lum.accentPress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
