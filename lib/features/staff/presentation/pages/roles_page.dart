import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/failures/staff_failure.dart';
import '../controllers/staff_controllers.dart';
import '../widgets/staff_member_row.dart';
import '../widgets/staff_role_card.dart';
import '../widgets/staff_segmented.dart';

class RolesPage extends ConsumerStatefulWidget {
  const RolesPage({super.key});

  @override
  ConsumerState<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends ConsumerState<RolesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      eyebrow: 'Team',
      title: 'Roles & permissions',
      description: 'Roles bundle what someone can do. Lower level = more privilege.',
      actions: [
        if (_tab == 0)
          PermissionGate(
            module: 'settings',
            action: 'create',
            child: AppButton(
              label: 'New role',
              size: AppButtonSize.sm,
              icon: LucideIcons.plus,
              onPressed: () => context.push('/settings/roles/new'),
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaffSegmented(
            labels: const ['Roles', 'Members'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 20),
          _tab == 0 ? const _RolesTab() : const _MembersTab(),
        ],
      ),
    );
  }
}

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rolesControllerProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppErrorState(
        title: "Unable to load roles",
        body: e is StaffFailure ? e.message : 'Please try again.',
        onRetry: () => ref.read(rolesControllerProvider.notifier).refresh(),
      ),
      data: (roles) => Column(
        children: [
          for (final r in roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StaffRoleCard(
                role: r,
                // Only custom roles are editable; system roles are immutable
                // (update_role_permissions rejects them), so no tap.
                onTap: r.isSystemRole
                    ? null
                    : () => context.push('/settings/roles/${r.id}', extra: r),
              ),
            ),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenantUsersControllerProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppErrorState(
        title: "Unable to load members",
        body: e is StaffFailure ? e.message : 'Please try again.',
        onRetry: () => ref.read(tenantUsersControllerProvider.notifier).refresh(),
      ),
      data: (users) => Column(
        children: [
          for (final u in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StaffMemberRow(
                user: u,
                trailing: PermissionGate(
                  module: 'users',
                  action: 'update',
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AppButton(
                      label: 'Change',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      onPressed: () =>
                          context.push('/settings/users/${u.id}/role'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
