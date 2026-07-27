import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../controllers/staff_controllers.dart';
import '../widgets/staff_option_card.dart';
import '../widgets/staff_segmented.dart';

class StaffInviteCreatePage extends ConsumerStatefulWidget {
  const StaffInviteCreatePage({
    super.key,
    this.employeeId,
    this.prefillName,
    this.prefillEmail,
    this.branchId,
  });

  final String? employeeId;
  final String? prefillName;
  final String? prefillEmail;

  /// The employee's branch when arriving from HR — preselected so the caller
  /// doesn't re-pick a branch the employee record already carries.
  final String? branchId;

  @override
  ConsumerState<StaffInviteCreatePage> createState() =>
      _StaffInviteCreatePageState();
}

class _StaffInviteCreatePageState extends ConsumerState<StaffInviteCreatePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _roleId;
  final Set<String> _branchIds = {};
  int _expiryHours = 72;
  bool _saving = false;
  String? _error;

  // Ordered so the segmented control's index maps to a value.
  static const _expiry = [
    (24, '1 day'),
    (72, '3 days'),
    (168, '1 week'),
    (720, '30 days'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.prefillName ?? '';
    _emailCtrl.text = widget.prefillEmail ?? '';
    // Seeded here, not in the branch list's data builder: that closure re-runs
    // on every setState (role tap, expiry change), which would re-tick a branch
    // the user deliberately unticked. The tile reads _branchIds via contains,
    // so seeding before the list resolves is fine — it lights up on arrival.
    if (widget.branchId != null) _branchIds.add(widget.branchId!);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Branch ids the picker is actually showing — empty while the list loads.
  Set<String> _visibleBranchIds() =>
      ref.read(branchOptionsProvider).asData?.value.map((b) => b.id).toSet() ??
      const <String>{};

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Only send branches the caller can see: listBranches returns every tenant
    // branch, but create_staff_invite requires the caller be assigned to each.
    // A seeded branch outside that set would fail with a raw
    // "branch not assigned" the user cannot act on.
    final visible = _visibleBranchIds();
    final (created, failure) = await ref.read(staffActionsProvider).createInvite(
          roleId: _roleId!,
          branchIds: _branchIds.where(visible.contains).toList(),
          fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          employeeId: widget.employeeId,
          expiresInHours: _expiryHours,
        );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    context.pushReplacement('/staff/invite/${created!.inviteId}/qr', extra: created);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final rolesAsync = ref.watch(rolesControllerProvider);
    final branchesAsync = ref.watch(branchOptionsProvider);
    final prefilled = (widget.prefillName ?? widget.prefillEmail) != null;
    // Gate on a branch the picker is showing, so a seeded-but-unassignable
    // branch can't enable the button with nothing visibly ticked.
    final visibleBranchIds =
        branchesAsync.asData?.value.map((b) => b.id).toSet() ?? const <String>{};
    final valid = _roleId != null && _branchIds.any(visibleBranchIds.contains);
    // True only while the seeded branch is both visible and still ticked, so
    // the copy below disappears the moment the user unticks it.
    final branchSeeded = widget.branchId != null &&
        visibleBranchIds.contains(widget.branchId) &&
        _branchIds.contains(widget.branchId);
    final expiryIndex = _expiry.indexWhere((e) => e.$1 == _expiryHours);

    return AppDetailScaffold(
      eyebrow: 'Invites',
      title: 'Invite a teammate',
      description: prefilled
          ? 'Prefilled from the HR profile for '
              '${widget.prefillName ?? 'this employee'}.'
              '${branchSeeded ? ' Their branch is already selected — add more '
                  'if they work across branches.' : ''}'
          : 'Send a one-time code that locks to their role and branches.',
      maxContentWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameCtrl,
            label: 'Name (optional)',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email (locks the code to this address)',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 22),
          _label(lum, 'Role'),
          const SizedBox(height: 10),
          rolesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _loadError(lum, 'Unable to load roles.'),
            data: (roles) => Column(
              children: [
                for (final r in roles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaffOptionCard(
                      title: r.name,
                      trailingText: '${r.permissionCount} permissions',
                      selected: _roleId == r.id,
                      onTap: () => setState(() => _roleId = r.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _label(lum, 'Branches · pick at least one'),
          const SizedBox(height: 10),
          branchesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _loadError(lum, 'Unable to load branches.'),
            data: (branches) => Column(
              children: [
                for (final b in branches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BranchTile(
                      name: b.name,
                      selected: _branchIds.contains(b.id),
                      onToggle: () => setState(() {
                        if (!_branchIds.remove(b.id)) _branchIds.add(b.id);
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _label(lum, 'Expires in'),
          const SizedBox(height: 10),
          StaffSegmented(
            labels: [for (final e in _expiry) e.$2],
            index: expiryIndex < 0 ? 1 : expiryIndex,
            onChanged: (i) => setState(() => _expiryHours = _expiry[i].$1),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Create invite',
            fullWidth: true,
            loading: _saving,
            onPressed: (_saving || !valid) ? null : _submit,
          ),
          if (!valid) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                _roleId == null
                    ? 'Choose a role to continue.'
                    : 'Select at least one branch.',
                style: AppTypography.footnote.copyWith(color: lum.g500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(LumColors lum, String text) => Text(
        text,
        style: AppTypography.label.copyWith(color: lum.g700),
      );

  Widget _loadError(LumColors lum, String text) => Text(
        text,
        style: AppTypography.footnote.copyWith(color: lum.dangerText),
      );
}

/// A branch multiselect tile: clay checkbox in a bordered card that highlights
/// when picked. Tapping anywhere toggles it.
class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.name,
    required this.selected,
    required this.onToggle,
  });

  final String name;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? lum.accentSoft : lum.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? lum.accent : lum.hairline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AppCheckbox(value: selected, onChanged: (_) => onToggle()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTypography.body.copyWith(color: lum.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
