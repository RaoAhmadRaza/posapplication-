import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/staff_entities.dart';
import '../controllers/staff_controllers.dart';
import '../widgets/staff_option_card.dart';
import '../widgets/staff_ui.dart';

class UserRolePage extends ConsumerStatefulWidget {
  const UserRolePage({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<UserRolePage> createState() => _UserRolePageState();
}

class _UserRolePageState extends ConsumerState<UserRolePage> {
  String? _roleId;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_roleId == null) {
      setState(() => _error = 'Select a role.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure =
        await ref.read(staffActionsProvider).updateUserRole(widget.userId, _roleId!);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final usersAsync = ref.watch(tenantUsersControllerProvider);
    final rolesAsync = ref.watch(rolesControllerProvider);

    final TenantUser? user = usersAsync.maybeWhen(
      data: (users) =>
          users.where((u) => u.id == widget.userId).cast<TenantUser?>().firstOrNull,
      orElse: () => null,
    );
    _roleId ??= user?.roleId;
    final changed = user != null && _roleId != user.roleId;

    return AppDetailScaffold(
      eyebrow: 'Members',
      title: 'Change role',
      maxContentWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) _MemberHeader(user: user),
          const SizedBox(height: 22),
          Text('New role',
              style: AppTypography.label.copyWith(color: lum.g700)),
          const SizedBox(height: 10),
          rolesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => AppInlineBanner(
                message: 'Unable to load roles.', type: BannerType.error),
            data: (roles) => Column(
              children: [
                for (final r in roles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaffOptionCard(
                      title: r.name,
                      subtitle: r.description,
                      showRadio: true,
                      selected: _roleId == r.id,
                      onTap: () => setState(() => _roleId = r.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('User counts on both roles update when you save.',
              style: AppTypography.footnote.copyWith(color: lum.g500)),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 22),
          AppButton(
            label: 'Save role',
            fullWidth: true,
            loading: _saving,
            onPressed: (_saving || !changed) ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.user});
  final TenantUser user;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final name = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : (user.email ?? 'User');
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                staffInitials(user.fullName, user.email),
                style: AppTypography.title2
                    .copyWith(fontSize: 16, color: lum.accentPress),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headline
                        .copyWith(fontSize: 16, color: lum.textPrimary)),
                if (user.email != null && user.fullName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(user.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(color: lum.g500)),
                ],
                const SizedBox(height: 4),
                Text('Currently ${user.roleName ?? 'no role'}',
                    style: AppTypography.footnote.copyWith(color: lum.accentPress)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
