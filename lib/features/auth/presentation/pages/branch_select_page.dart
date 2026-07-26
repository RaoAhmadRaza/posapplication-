import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/auth_hero_scaffold.dart';
import '../../../../core/supabase.dart';
import '../../domain/entities/branch.dart';
import '../controllers/branch_controller.dart';

class BranchSelectPage extends ConsumerStatefulWidget {
  const BranchSelectPage({super.key});

  @override
  ConsumerState<BranchSelectPage> createState() => _BranchSelectPageState();
}

class _BranchSelectPageState extends ConsumerState<BranchSelectPage> {
  // Id of the branch whose selection is in flight; blocks a second tap and
  // drives the inline spinner on that tile.
  String? _selectingId;

  @override
  Widget build(BuildContext context) {
    final branchesState = ref.watch(userBranchesProvider);
    final currentBranch = ref.watch(currentBranchProvider);

    return AuthHeroScaffold(
      child: AuthFormCard(
        title: 'Select a branch',
        subtitle: 'Choose the branch you want to work with.',
        // Escape hatch present on every state so the user is never trapped.
        footer: AppButton(
          label: 'Not you? Sign out',
          variant: AppButtonVariant.plain,
          fullWidth: true,
          onPressed: _signOut,
        ),
        children: [
          branchesState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppInlineBanner(
                  message: 'Unable to load branches.',
                  type: BannerType.error,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  variant: AppButtonVariant.tinted,
                  fullWidth: true,
                  icon: Icons.refresh,
                  onPressed: _retry,
                ),
              ],
            ),
            data: (branches) {
              if (branches.isEmpty) return const _EmptyBranches();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final branch in branches) ...[
                    _BranchTile(
                      branch: branch,
                      isCurrent: currentBranch?.id == branch.id,
                      isSelecting: _selectingId == branch.id,
                      // Disable every tile while any selection is in flight.
                      onTap: _selectingId == null
                          ? () => _onSelect(branch)
                          : null,
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

  Future<void> _onSelect(Branch branch) async {
    if (_selectingId != null) return;
    setState(() => _selectingId = branch.id);
    await ref.read(userBranchesProvider.notifier).selectBranch(branch);
    if (mounted) setState(() => _selectingId = null);
  }

  void _retry() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    ref.read(userBranchesProvider.notifier).load(userId);
  }

  Future<void> _signOut() async {
    // Router redirect returns to /login once the session clears.
    await supabase.auth.signOut();
  }
}

/// Neutral empty state — no branches assigned yet. Not an error.
class _EmptyBranches extends StatelessWidget {
  const _EmptyBranches();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 40, color: lum.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No branches available',
            style: AppTypography.headline.copyWith(color: lum.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Ask an administrator to assign you to a branch.',
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(color: lum.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Selectable clay branch row — Lumen accent ring + check on the active one.
class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.branch,
    required this.isCurrent,
    required this.isSelecting,
    required this.onTap,
  });

  final Branch branch;
  final bool isCurrent;
  final bool isSelecting;
  final VoidCallback? onTap;

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
                if (isSelecting)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(lum.accent),
                    ),
                  )
                else
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
