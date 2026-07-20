import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../domain/entities/branch.dart';
import '../controllers/branch_controller.dart';

class BranchSelectPage extends ConsumerWidget {
  const BranchSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesState = ref.watch(userBranchesProvider);
    final currentBranch = ref.watch(currentBranchProvider);

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Select a branch',
        subtitle: 'Choose the branch you want to work with.',
        children: [
          branchesState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => const AppInlineBanner(
              message: 'Could not load branches.',
              type: BannerType.error,
            ),
            data: (branches) {
              if (branches.isEmpty) {
                return const AppInlineBanner(
                  message: 'No branches available.',
                  type: BannerType.error,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final branch in branches) ...[
                    _BranchTile(
                      branch: branch,
                      isCurrent: currentBranch?.id == branch.id,
                      onTap: () => _onSelect(ref, context, branch),
                    ),
                    if (branch != branches.last)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _onSelect(WidgetRef ref, BuildContext context, Branch branch) async {
    await ref.read(userBranchesProvider.notifier).selectBranch(branch);
  }
}

/// Selectable clay branch row — Lumen accent ring + check on the active one.
class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.branch,
    required this.isCurrent,
    required this.onTap,
  });

  final Branch branch;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final radius = BorderRadius.circular(AppRadius.md);
    final subtitle = branch.isMain ? 'Main branch · ${branch.code}' : branch.code;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isCurrent ? lum.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ClayContainer(
            variant: isCurrent ? ClayVariant.raised : ClayVariant.soft,
            color: lum.surface,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                _CodeBadge(code: branch.code, isCurrent: isCurrent, lum: lum),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: AppTypography.headline
                            .copyWith(color: lum.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.footnote
                            .copyWith(color: lum.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isCurrent ? Icons.check_circle : Icons.circle_outlined,
                  color: isCurrent ? lum.accent : lum.g300,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({
    required this.code,
    required this.isCurrent,
    required this.lum,
  });

  final String code;
  final bool isCurrent;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isCurrent ? lum.accent : lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: AppTypography.label.copyWith(
          color: isCurrent ? Colors.white : lum.accent,
          fontSize: 13,
        ),
      ),
    );
  }
}
