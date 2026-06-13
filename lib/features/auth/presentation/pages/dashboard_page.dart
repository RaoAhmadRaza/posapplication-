import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/supabase.dart';
import '../controllers/profile_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Dashboard', style: AppTypography.largeTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user?.email ?? '',
                style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _DashboardProfileCard(userId: user?.id ?? ''),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.textHint),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Your dashboard will show sales,\ninventory and alerts here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardProfileCard extends ConsumerWidget {
  final String userId;
  const _DashboardProfileCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.value;

    if (profile == null) return const SizedBox.shrink();

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
              style: AppTypography.headline.copyWith(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${profile.fullName}',
                style: AppTypography.headline,
              ),
              if (profile.roleName != null)
                Text(
                  '${profile.roleName} · ${profile.tenantName ?? ''}',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
