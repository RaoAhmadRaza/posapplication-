import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/failures/staff_failure.dart';
import '../controllers/staff_controllers.dart';

class RolesPage extends ConsumerWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Roles & permissions', style: AppTypography.headline),
          bottom: const TabBar(tabs: [Tab(text: 'Roles'), Tab(text: 'Members')]),
        ),
        floatingActionButton: PermissionGate(
          module: 'settings',
          action: 'create',
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/settings/roles/new'),
            backgroundColor: AppColors.accent,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New role', style: TextStyle(color: Colors.white)),
          ),
        ),
        body: const SafeArea(child: TabBarView(children: [_RolesTab(), _MembersTab()])),
      ),
    );
  }
}

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rolesControllerProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(rolesControllerProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorList(e, 'Could not load roles.'),
        data: (roles) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            for (final r in roles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: AppTypography.body),
                            const SizedBox(height: 2),
                            Text(
                              '${r.permissionCount} permission${r.permissionCount == 1 ? '' : 's'} · ${r.userCount} user${r.userCount == 1 ? '' : 's'}',
                              style: AppTypography.footnote
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (r.isSystemRole)
                        Text('System',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenantUsersControllerProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(tenantUsersControllerProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorList(e, 'Could not load members.'),
        data: (users) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            for (final u in users)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName?.isNotEmpty == true ? u.fullName! : (u.email ?? 'User'),
                                style: AppTypography.body),
                            const SizedBox(height: 2),
                            Text(u.roleName ?? 'No role',
                                style: AppTypography.footnote
                                    .copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      PermissionGate(
                        module: 'users',
                        action: 'update',
                        child: TextButton(
                          onPressed: () => context.push('/settings/users/${u.id}/role'),
                          child: const Text('Change'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _errorList(Object e, String fallback) => ListView(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: AppInlineBanner(
          message: e is StaffFailure ? e.message : fallback,
          type: BannerType.error,
        ),
      ),
    ]);
