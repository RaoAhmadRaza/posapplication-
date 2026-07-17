import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/staff_entities.dart';
import '../controllers/staff_controllers.dart';

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
    final usersAsync = ref.watch(tenantUsersControllerProvider);
    final rolesAsync = ref.watch(rolesControllerProvider);

    final TenantUser? user = usersAsync.maybeWhen(
      data: (users) =>
          users.where((u) => u.id == widget.userId).cast<TenantUser?>().firstOrNull,
      orElse: () => null,
    );
    _roleId ??= user?.roleId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Change role', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            if (user != null) ...[
              Text(user.fullName?.isNotEmpty == true ? user.fullName! : (user.email ?? 'User'),
                  style: AppTypography.headline),
              const SizedBox(height: 4),
              Text('Current role: ${user.roleName ?? 'None'}',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('New role',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            rolesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => AppInlineBanner(
                  message: 'Could not load roles.', type: BannerType.error),
              data: (roles) => DropdownButtonFormField<String>(
                initialValue: _roleId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _roleId = v),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
