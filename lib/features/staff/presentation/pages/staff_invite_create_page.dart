import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../controllers/staff_controllers.dart';

class StaffInviteCreatePage extends ConsumerStatefulWidget {
  const StaffInviteCreatePage({
    super.key,
    this.employeeId,
    this.prefillName,
    this.prefillEmail,
  });

  final String? employeeId;
  final String? prefillName;
  final String? prefillEmail;

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

  static const _expiryOptions = {24: '1 day', 72: '3 days', 168: '1 week', 720: '30 days'};

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.prefillName ?? '';
    _emailCtrl.text = widget.prefillEmail ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_roleId == null) {
      setState(() => _error = 'Select a role.');
      return;
    }
    if (_branchIds.isEmpty) {
      setState(() => _error = 'Select at least one branch.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final (created, failure) = await ref.read(staffActionsProvider).createInvite(
          roleId: _roleId!,
          branchIds: _branchIds.toList(),
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
    final rolesAsync = ref.watch(rolesControllerProvider);
    final branchesAsync = ref.watch(branchOptionsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Invite staff', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Full name (optional)',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailCtrl,
              label: 'Email (locks the invite to this address)',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Role', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            rolesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text('Could not load roles.',
                  style: AppTypography.footnote.copyWith(color: AppColors.destructive)),
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
            const SizedBox(height: AppSpacing.lg),
            Text('Branches', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            branchesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text('Could not load branches.',
                  style: AppTypography.footnote.copyWith(color: AppColors.destructive)),
              data: (branches) => Column(
                children: [
                  for (final b in branches)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(b.name, style: AppTypography.body),
                      value: _branchIds.contains(b.id),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _branchIds.add(b.id);
                        } else {
                          _branchIds.remove(b.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Expires in', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _expiryHours,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final e in _expiryOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _expiryHours = v ?? 72),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Create invite',
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
