import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_settings_row.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../../core/state/theme_controller.dart';
import '../../domain/usecases/get_enrolled_factor_id.dart';
import '../../../../core/services/pin_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/permission_controller.dart';
import '../controllers/profile_controller.dart';

/// Profile & security — the account surface the settings hub links to.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Profile & security',
      description: 'Your account, sign-in and this device.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProfileCard(),
          const SizedBox(height: AppSpacing.lg),
          const _SignInSection(),
          const SizedBox(height: AppSpacing.lg),
          const _AdminSection(),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Log out',
            variant: AppButtonVariant.destructive,
            icon: LucideIcons.logOut,
            fullWidth: true,
            onPressed: () async {
              final ok = await showAppConfirm(
                context,
                title: 'Log out?',
                message:
                    "You'll need to sign in again to access your account.",
                confirmLabel: 'Log out',
                destructive: true,
              );
              if (!ok) return;
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

/// Avatar, name, email and the role / store the account belongs to.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final profileState = ref.watch(profileControllerProvider);

    if (profileState.isLoading) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // ClayVariant.lumen paints no fill of its own, so the accent is set
          // explicitly here rather than relying on the variant.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: lum.accent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile.fullName.isNotEmpty
                    ? profile.fullName[0].toUpperCase()
                    : '?',
                style: AppTypography.title2.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.fullName,
                  style: AppTypography.title2.copyWith(
                    fontSize: 21,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 13,
                    color: lum.g500,
                  ),
                ),
                if (profile.roleName != null || profile.tenantName != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (profile.roleName != null)
                        AppPill(
                          label: profile.roleName!,
                          tone: AppPillTone.lumen,
                          showDot: false,
                        ),
                      if (profile.tenantName != null)
                        AppPill(label: profile.tenantName!, showDot: false),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Appearance and sign-in: theme, PIN, biometrics, authenticator.
class _SignInSection extends ConsumerStatefulWidget {
  const _SignInSection();

  @override
  ConsumerState<_SignInSection> createState() => _SignInSectionState();
}

class _SignInSectionState extends ConsumerState<_SignInSection> {
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
    final canBiometrics =
        hasPin ? await LocalAuthentication().canCheckBiometrics : false;
    final biometricsOn =
        hasPin ? await PinService.instance.isBiometricsEnabled() : false;
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
    final themeRow = AppSettingsRow(
      icon: LucideIcons.moon,
      title: 'Counter mode (dark)',
      subtitle: 'Easier on the eyes during long or low-light shifts.',
      trailing: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.mode,
        builder: (context, mode, _) => AppToggle(
          value: mode == ThemeMode.dark,
          semanticLabel: 'Counter mode',
          onChanged: (on) =>
              ThemeController.set(on ? ThemeMode.dark : ThemeMode.light),
        ),
      ),
    );

    if (!_checked) {
      return AppSettingsGroup(
        title: 'Appearance & sign-in',
        children: [
          themeRow,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    return AppSettingsGroup(
      title: 'Appearance & sign-in',
      children: [
        themeRow,
        AppSettingsRow(
          icon: LucideIcons.lock,
          title: _hasPin ? 'Change PIN' : 'Set PIN',
          subtitle: _hasPin
              ? 'Used for quick unlock and approving actions.'
              : 'Add a 4-digit PIN for quick login.',
          meta: _hasPin
              ? const AppPill(label: 'PIN set', tone: AppPillTone.success)
              : null,
          onTap: () => context.push('/pin-setup'),
        ),
        AppSettingsRow(
          icon: LucideIcons.shieldCheck,
          title: 'Biometric unlock',
          subtitle: _showBiometrics
              ? 'Use Face ID or fingerprint on this device.'
              : _hasPin
                  ? 'Not available on this device.'
                  : 'Set a PIN first.',
          trailing: AppToggle(
            value: _biometricsOn,
            enabled: _showBiometrics,
            semanticLabel: 'Biometric unlock',
            onChanged: _toggleBiometrics,
          ),
        ),
        AppSettingsRow(
          icon: LucideIcons.smartphone,
          title: _hasMfa ? 'Authenticator app' : 'Set up authenticator',
          subtitle: _hasMfa
              ? 'Two-factor authentication is active.'
              : 'Add a second step with an authenticator app.',
          meta: AppPill(
            label: _hasMfa ? 'Active' : 'Not set',
            tone: _hasMfa ? AppPillTone.success : AppPillTone.neutral,
            showDot: _hasMfa,
          ),
          onTap: () => context.push('/mfa-enroll'),
        ),
      ],
    );
  }
}

/// Security & devices — admin-only rows.
///
/// The rows are filtered against the permission matrix BEFORE the group is
/// built rather than each being wrapped in a [PermissionGate]: a gated-out row
/// still occupies a slot in the group, which would leave its hairline behind as
/// a stray double rule. The permission keys are unchanged.
class _AdminSection extends ConsumerWidget {
  const _AdminSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value;
    bool can(String key) => matrix?.contains(key) ?? false;

    final rows = <Widget>[
      if (can('settings:update'))
        AppSettingsRow(
          icon: LucideIcons.monitor,
          title: 'Trusted devices',
          subtitle: 'Devices allowed to sign in without approval.',
          onTap: () => context.push('/devices'),
        ),
      if (can('settings:read')) ...[
        AppSettingsRow(
          icon: LucideIcons.smartphone,
          title: 'Active sessions',
          subtitle: "Where you're currently signed in.",
          onTap: () => context.push('/sessions'),
        ),
        AppSettingsRow(
          icon: LucideIcons.fileText,
          title: 'Security activity log',
          subtitle: 'Sign-ins, PIN changes and approvals.',
          onTap: () => context.push('/security-logs'),
        ),
      ],
      if (can('accounting:read'))
        AppSettingsRow(
          icon: LucideIcons.percent,
          title: 'Tax rules',
          subtitle: 'Rates and how tax posts to the ledger.',
          onTap: () => context.push('/accounting/tax-rules'),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppSettingsGroup(title: 'Security & devices', children: rows),
    );
  }
}
