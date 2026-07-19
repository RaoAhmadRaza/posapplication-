import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/staff_entities.dart';
import '../../domain/failures/staff_failure.dart';
import '../../domain/repositories/staff_repository.dart';
import '../controllers/staff_controllers.dart';

class RoleFormPage extends ConsumerStatefulWidget {
  const RoleFormPage({super.key, this.role});

  /// Non-null → edit an existing custom role's permissions. The backing RPC
  /// (update_role_permissions) only changes the permission set, so name/level
  /// are shown read-only in edit mode.
  final TenantRole? role;

  @override
  ConsumerState<RoleFormPage> createState() => _RoleFormPageState();
}

class _RoleFormPageState extends ConsumerState<RoleFormPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _hierarchy = 50;
  final Set<String> _selected = {}; // 'module:action'
  bool _saving = false;
  bool _prefilled = false;
  String? _error;

  bool get _isEdit => widget.role != null;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    if (role != null) {
      _nameCtrl.text = role.name;
      _descCtrl.text = role.description ?? '';
      _hierarchy = role.hierarchyLevel;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (!_isEdit && name.isEmpty) {
      setState(() => _error = 'Role name is required.');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one permission.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final permissions = _selected.map((key) {
      final parts = key.split(':');
      return PermissionGrant(module: parts[0], action: parts[1]);
    }).toList();

    // Edit → update permissions only (the guarded RPC rejects unheld grants,
    // system/own-role edits, and hierarchy violations; surfaced below).
    // Create → create_tenant_role.
    final StaffFailure? failure = _isEdit
        ? await ref
            .read(staffActionsProvider)
            .updateRolePermissions(widget.role!.id, permissions)
        : (await ref.read(staffActionsProvider).createRole(
              name: name,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              hierarchyLevel: _hierarchy,
              permissions: permissions,
            ))
            .$2;
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
    final catalogAsync = ref.watch(permissionCatalogProvider);

    // Edit mode: seed the selected set from the role's current permissions once.
    if (_isEdit) {
      ref.listen(rolePermissionsProvider(widget.role!.id), (_, next) {
        next.whenData((grants) {
          if (!_prefilled && mounted) {
            setState(() {
              _selected
                ..clear()
                ..addAll(grants.map((g) => '${g.module}:${g.action}'));
              _prefilled = true;
            });
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? 'Edit role' : 'New role',
            style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            if (_isEdit) ...[
              // Name/level are immutable via update_role_permissions — show them
              // read-only; only the permission set is editable here.
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(_nameCtrl.text, style: AppTypography.body),
                    ),
                    Text('Level $_hierarchy',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              AppTextField(
                controller: _nameCtrl,
                label: 'Role name',
                prefixIcon: Icons.shield_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descCtrl,
                label: 'Description (optional)',
                prefixIcon: Icons.notes,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Level (2 = high, 99 = low)',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted)),
                  ),
                  Text('$_hierarchy', style: AppTypography.body),
                ],
              ),
              Slider(
                value: _hierarchy.toDouble(),
                min: 2,
                max: 99,
                divisions: 97,
                label: '$_hierarchy',
                onChanged: (v) => setState(() => _hierarchy = v.round()),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('Permissions',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => AppInlineBanner(
                  message: 'Could not load permissions.', type: BannerType.error),
              data: (items) {
                final byModule = <String, List<String>>{};
                for (final it in items) {
                  byModule.putIfAbsent(it.module, () => []).add(it.action);
                }
                final modules = byModule.keys.toList()..sort();
                return Column(
                  children: [
                    for (final m in modules)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.toUpperCase(),
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted)),
                            for (final a in byModule[m]!..sort())
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(a, style: AppTypography.body),
                                value: _selected.contains('$m:$a'),
                                onChanged: (on) => setState(() {
                                  final k = '$m:$a';
                                  if (on == true) {
                                    _selected.add(k);
                                  } else {
                                    _selected.remove(k);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isEdit ? 'Save changes' : 'Create role',
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
