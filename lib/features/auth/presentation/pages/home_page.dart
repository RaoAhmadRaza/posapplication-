import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/supabase.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Home', style: AppTypography.largeTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.email ?? '',
                style: AppTypography.subhead.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _ProfileCard(userId: user.id),
              const Spacer(),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.destructive,
                icon: Icons.logout,
                onPressed: () {
                  ref.read(authControllerProvider.notifier).signOut();
                },
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  final String userId;
  const _ProfileCard({required this.userId});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).load(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    if (profileState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profileState.hasError) {
      return const AppInlineBanner(
        message: 'Could not load profile.',
        type: BannerType.error,
      );
    }

    final profile = profileState.value;
    if (profile == null) {
      return const AppInlineBanner(
        message: 'Could not load profile.',
        type: BannerType.error,
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Center(
                  child: Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName[0].toUpperCase()
                        : '?',
                    style: AppTypography.title2.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: AppTypography.headline),
                    Text(
                      profile.email,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.roleName != null || profile.tenantName != null) ...[
            const SizedBox(height: AppSpacing.base),
            Divider(color: AppColors.separator, height: 1),
            const SizedBox(height: AppSpacing.base),
            if (profile.roleName != null)
              _ProfileDetail(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: profile.roleName!,
              ),
            if (profile.roleName != null && profile.tenantName != null)
              const SizedBox(height: AppSpacing.sm),
            if (profile.tenantName != null)
              _ProfileDetail(
                icon: Icons.store_outlined,
                label: 'Store',
                value: profile.tenantName!,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: AppTypography.subhead.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        Text(value, style: AppTypography.subhead),
      ],
    );
  }
}
