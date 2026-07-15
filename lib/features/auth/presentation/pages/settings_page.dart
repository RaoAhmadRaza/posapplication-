import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/usecases/get_enrolled_factor_id.dart';
import '../../../../core/services/pin_service.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Settings', style: AppTypography.largeTitle),
              const SizedBox(height: AppSpacing.xxl),
              const _ProfileSection(),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Security'),
              const SizedBox(height: AppSpacing.sm),
              const _SecuritySection(),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Administration'),
              const SizedBox(height: AppSpacing.sm),
              const _AdminSection(),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Configuration'),
              const SizedBox(height: AppSpacing.sm),
              const _ConfigurationSection(),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.destructive,
                icon: Icons.logout,
                onPressed: () {
                  ref.read(authControllerProvider.notifier).signOut();
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.footnote.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    if (profileState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profileState.hasError || profileState.value == null) {
      return const AppInlineBanner(
        message: 'Could not load profile.',
        type: BannerType.error,
      );
    }

    final profile = profileState.value!;
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
                    style: AppTypography.title2.copyWith(color: AppColors.accent),
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
                      style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.roleName != null || profile.tenantName != null) ...[
            const SizedBox(height: AppSpacing.base),
            const Divider(color: AppColors.separator, height: 1),
            const SizedBox(height: AppSpacing.base),
            if (profile.roleName != null)
              _ProfileDetail(icon: Icons.badge_outlined, label: 'Role', value: profile.roleName!),
            if (profile.roleName != null && profile.tenantName != null)
              const SizedBox(height: AppSpacing.sm),
            if (profile.tenantName != null)
              _ProfileDetail(icon: Icons.store_outlined, label: 'Store', value: profile.tenantName!),
          ],
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.icon, required this.label, required this.value});
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
          style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
        ),
        Text(value, style: AppTypography.subhead),
      ],
    );
  }
}

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();

  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  bool _checked = false;
  bool _hasPin = false;
  bool _showBiometrics = false;
  bool _biometricsOn = false;
  bool _hasMfa = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasPin = await PinService.instance.hasPin();
    final canBiometrics = hasPin ? await LocalAuthentication().canCheckBiometrics : false;
    final biometricsOn = hasPin ? await PinService.instance.isBiometricsEnabled() : false;
    final (factorId, mfaFailure) =
        await ref.read(getEnrolledFactorIdUseCaseProvider).call();
    final hasMfa = mfaFailure == null && factorId != null;
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _showBiometrics = canBiometrics;
        _biometricsOn = biometricsOn;
        _hasMfa = hasMfa;
        _checked = true;
      });
    }
  }

  Future<void> _toggleBiometrics(bool v) async {
    await PinService.instance.setBiometricsEnabled(v);
    if (mounted) setState(() => _biometricsOn = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.lock_outline,
            title: _hasPin ? 'Change PIN' : 'Set PIN',
            subtitle: _hasPin ? 'Update your quick-login PIN.' : 'Add a 4-digit PIN for quick login.',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => context.push('/pin-setup'),
          ),
          _SettingsRow(
            icon: Icons.fingerprint,
            title: 'Biometric unlock',
            subtitle: _showBiometrics
                ? 'Use Face ID or fingerprint.'
                : _hasPin
                    ? 'Not available on this device.'
                    : 'Set a PIN first.',
            trailing: Switch(
              value: _biometricsOn,
              activeTrackColor: AppColors.accent,
              onChanged: _showBiometrics ? _toggleBiometrics : null,
            ),
          ),
          _SettingsRow(
            icon: _hasMfa ? Icons.phone_android : Icons.security_outlined,
            title: _hasMfa ? 'Authenticator app' : 'Set up authenticator',
            subtitle: _hasMfa ? 'Two-factor authentication is active.' : 'Add extra security to your account.',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => context.push('/mfa-enroll'),
          ),
        ],
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  const _AdminSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          PermissionGate(
            module: 'settings',
            action: 'update',
            child: _SettingsRow(
              icon: Icons.devices,
              title: 'Trusted devices',
              subtitle: 'Manage registered devices.',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => context.push('/devices'),
            ),
          ),
          PermissionGate(
            module: 'settings',
            action: 'read',
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.people_outline,
                  title: 'Active sessions',
                  subtitle: 'View and manage user sessions.',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () => context.push('/sessions'),
                ),
                _SettingsRow(
                  icon: Icons.history,
                  title: 'Security activity log',
                  subtitle: 'Recent account and device activity.',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () => context.push('/security-logs'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationSection extends StatelessWidget {
  const _ConfigurationSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: PermissionGate(
        module: 'accounting',
        action: 'read',
        child: _SettingsRow(
          icon: Icons.percent,
          title: 'Tax rules',
          subtitle: 'Rates applied as defaults on products and sales.',
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: () => context.push('/accounting/tax-rules'),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.separator, height: 1),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(icon, color: AppColors.accent, size: 22)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.headline),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
