import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_settings_row.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../widgets/settings_nav_tile.dart';

/// The Settings tab: a hub linking to every configuration surface.
/// Self-service groups (Account, App) are visible to every authenticated
/// user — a CASHIER must be able to reach own-account security (PIN, biometric,
/// MFA enrolment) without an admin-tier permission. The tenant-admin group
/// (Workspace) is gated settings:read; write actions on the sub-pages are
/// further gated settings:update.
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            return SingleChildScrollView(
              padding: narrow
                  ? const EdgeInsets.fromLTRB(16, 20, 16, 40)
                  : const EdgeInsets.fromLTRB(32, 32, 32, 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Settings',
                        style: AppTypography.title1.copyWith(
                          fontSize: narrow ? 26 : 30,
                          color: lum.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          'Manage your account, your business and how the app '
                          'behaves. Some sections need admin access.',
                          style:
                              AppTypography.subhead.copyWith(color: lum.g500),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Self-service — always visible.
                      AppSettingsGroup(
                        title: 'Account',
                        children: [
                          SettingsNavTile(
                            icon: LucideIcons.user,
                            title: 'Profile & security',
                            subtitle: 'Your account, PIN and sign-in',
                            tone: AppSettingsRowTone.lumen,
                            showDivider: false,
                            onTap: () => context.push('/settings/profile'),
                          ),
                        ],
                      ),

                      // Tenant-admin group — gated settings:read (hidden for
                      // CASHIER). The whole block collapses with its spacer so
                      // no stray gap is left behind.
                      const PermissionGate(
                        module: 'settings',
                        action: 'read',
                        child: _WorkspaceGroup(),
                      ),

                      // Self-service — always visible.
                      const SizedBox(height: 24),
                      AppSettingsGroup(
                        title: 'App',
                        children: [
                          SettingsNavTile(
                            icon: LucideIcons.slidersHorizontal,
                            title: 'Preferences',
                            subtitle: 'Theme, language, default branch',
                            showDivider: false,
                            onTap: () => context.push('/settings/preferences'),
                          ),
                          SettingsNavTile(
                            icon: LucideIcons.bell,
                            title: 'Notifications',
                            subtitle: 'Alerts and reminders',
                            onTap: () =>
                                context.push('/notifications/settings'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const _VersionFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceGroup extends StatelessWidget {
  const _WorkspaceGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        AppSettingsGroup(
          title: 'Workspace',
          children: [
            SettingsNavTile(
              icon: LucideIcons.users,
              title: 'Staff',
              subtitle: 'People who can sign in and sell',
              showDivider: false,
              onTap: () => context.push('/staff'),
            ),
            SettingsNavTile(
              icon: LucideIcons.shield,
              title: 'Roles & permissions',
              subtitle: 'What each role is allowed to do',
              onTap: () => context.push('/settings/roles'),
            ),
            SettingsNavTile(
              icon: LucideIcons.briefcase,
              title: 'Business settings',
              subtitle: 'Address, tax number, logo, receipt',
              onTap: () => context.push('/settings/business'),
            ),
            SettingsNavTile(
              icon: LucideIcons.mapPin,
              title: 'Branches',
              subtitle: 'Locations you operate',
              onTap: () => context.push('/settings/branches'),
            ),
            SettingsNavTile(
              icon: LucideIcons.creditCard,
              title: 'Payment methods',
              subtitle: 'How customers pay',
              onTap: () => context.push('/settings/payment-methods'),
            ),
            SettingsNavTile(
              icon: LucideIcons.percent,
              title: 'Tax rules',
              subtitle: 'Rates and how tax posts',
              onTap: () => context.push('/accounting/tax-rules'),
            ),
            SettingsNavTile(
              icon: LucideIcons.hash,
              title: 'Number series',
              subtitle: 'Invoice & document numbering',
              onTap: () => context.push('/settings/number-series'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Build stamp. The version is read from the real package info rather than
/// hardcoded, so it cannot drift from what actually shipped.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final suffix = _version == null ? '' : ' · v$_version';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        'LUMINA POS · Stock Bridge ERP$suffix',
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(color: lum.g400),
      ),
    );
  }
}
