import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
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

  static const _moduleIcon = <String, IconData>{
    'sales': LucideIcons.shoppingCart,
    'inventory': LucideIcons.package,
    'users': LucideIcons.usersRound,
    'settings': LucideIcons.settings,
    'reports': LucideIcons.chartColumn,
    'purchase': LucideIcons.truck,
    'accounting': LucideIcons.calculator,
    'hr': LucideIcons.idCard,
    'repair': LucideIcons.wrench,
    'notifications': LucideIcons.bell,
  };

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
              name: _nameCtrl.text.trim(),
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
    final lum = context.lum;
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

    final nameOk = _isEdit || _nameCtrl.text.trim().isNotEmpty;
    final valid = nameOk && _selected.isNotEmpty;
    final levelWord = _hierarchy <= 10
        ? 'high privilege'
        : _hierarchy <= 40
            ? 'medium privilege'
            : 'low privilege';

    return AppDetailScaffold(
      eyebrow: 'Roles',
      title: _isEdit ? 'Edit role' : 'New role',
      maxContentWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit)
            _IdentityCard(role: widget.role!)
          else ...[
            _label(lum, 'Role name'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _nameCtrl,
              label: 'Role name',
              prefixIcon: Icons.shield_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _label(lum, 'Description (optional)'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _descCtrl,
              label: 'Description (optional)',
              prefixIcon: Icons.notes,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _label(lum, 'Hierarchy level')),
                Text(
                  '$_hierarchy · $levelWord',
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
            Slider(
              value: _hierarchy.toDouble(),
              min: 2,
              max: 99,
              divisions: 97,
              label: '$_hierarchy',
              activeColor: lum.accent,
              onChanged: (v) => setState(() => _hierarchy = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('2 — highest privilege',
                    style: AppTypography.caption.copyWith(color: lum.g400)),
                Text('99 — lowest',
                    style: AppTypography.caption.copyWith(color: lum.g400)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Permissions',
                    style: AppTypography.title3.copyWith(color: lum.textPrimary)),
              ),
              Text('${_selected.length} selected',
                  style: AppTypography.footnote.copyWith(color: lum.accentPress)),
            ],
          ),
          const SizedBox(height: 12),
          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PermissionGroup(
                        module: m,
                        icon: _moduleIcon[m] ?? LucideIcons.shield,
                        actions: byModule[m]!..sort(),
                        selected: _selected,
                        onToggle: (key) => setState(() {
                          if (!_selected.remove(key)) _selected.add(key);
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: _isEdit ? 'Save changes' : 'Create role',
            fullWidth: true,
            loading: _saving,
            onPressed: (_saving || !valid) ? null : _save,
          ),
          if (!valid) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                nameOk
                    ? 'Select at least one permission.'
                    : 'Give the role a name.',
                style: AppTypography.footnote.copyWith(color: lum.g500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(LumColors lum, String text) =>
      Text(text, style: AppTypography.label.copyWith(color: lum.g700));
}

/// Read-only identity card shown when editing — name and level are fixed after
/// creation, only permissions change.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.role});
  final TenantRole role;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
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
            width: 44,
            height: 44,
            child: Icon(LucideIcons.shield, size: 20, color: lum.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.name,
                    style: AppTypography.headline
                        .copyWith(fontSize: 15, color: lum.textPrimary)),
                const SizedBox(height: 2),
                Text('Name and level are fixed after creation — only '
                    'permissions change here.',
                    style: AppTypography.footnote.copyWith(color: lum.g500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Lv ${role.hierarchyLevel}',
                  style: AppTypography.headline
                      .copyWith(fontSize: 15, color: lum.textPrimary)),
              Text('privilege',
                  style: AppTypography.caption.copyWith(color: lum.g400)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One module's permission block: an icon header over tappable checkbox rows.
class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({
    required this.module,
    required this.icon,
    required this.actions,
    required this.selected,
    required this.onToggle,
  });

  final String module;
  final IconData icon;
  final List<String> actions;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: lum.g500),
              const SizedBox(width: 8),
              Text(
                module[0].toUpperCase() + module.substring(1),
                style: AppTypography.label.copyWith(color: lum.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggle('$module:$a'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AppCheckbox(
                        value: selected.contains('$module:$a'),
                        onChanged: (_) => onToggle('$module:$a'),
                      ),
                      const SizedBox(width: 12),
                      Text(a,
                          style: AppTypography.body
                              .copyWith(color: lum.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
