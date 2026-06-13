import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/responsive_form_scaffold.dart';
import '../../domain/entities/branch.dart';
import '../controllers/branch_controller.dart';

class BranchSelectPage extends ConsumerWidget {
  const BranchSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesState = ref.watch(userBranchesProvider);
    final currentBranch = ref.watch(currentBranchProvider);

    return ResponsiveFormScaffold(
      title: 'Select a branch',
      subtitle: 'Choose the branch you want to work with.',
      child: branchesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            children: [
              const SizedBox(height: AppSpacing.sm),
              ...branches.map((branch) {
                final isCurrent = currentBranch?.id == branch.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _BranchCard(
                    branch: branch,
                    isCurrent: isCurrent,
                    onTap: () => _onSelect(ref, context, branch),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _onSelect(WidgetRef ref, BuildContext context, Branch branch) async {
    await ref.read(userBranchesProvider.notifier).selectBranch(branch);
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.isCurrent,
    required this.onTap,
  });

  final Branch branch;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  branch.code,
                  style: AppTypography.headline.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branch.name, style: AppTypography.headline),
                  if (branch.isMain)
                    Text(
                      'Main branch · ${branch.code}',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle, color: AppColors.accent, size: 24),
          ],
        ),
      ),
    );
  }
}
