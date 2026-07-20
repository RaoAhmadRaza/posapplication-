import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/sessions_controller.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'settings',
      action: 'read',
      child: const _SessionsContent(),
    );
  }
}

class _SessionsContent extends ConsumerStatefulWidget {
  const _SessionsContent();

  @override
  ConsumerState<_SessionsContent> createState() => _SessionsContentState();
}

class _SessionsContentState extends ConsumerState<_SessionsContent> {
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sessionsControllerProvider.notifier).load();
    });
  }

  Future<void> _revoke(String userId) async {
    final ok = await showAppConfirm(
      context,
      title: 'Sign out this session?',
      message: 'The device on this session will need to sign in again.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;

    setState(() => _revokingId = userId);
    await ref.read(sessionsControllerProvider.notifier).revoke(userId);
    if (!mounted) return;
    setState(() => _revokingId = null);
    showAppToast(context, 'Session signed out', type: BannerType.success);
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final state = ref.watch(sessionsControllerProvider);

    return Scaffold(
      backgroundColor: lum.paper,
      appBar: AppBar(
        backgroundColor: lum.paper,
        surfaceTintColor: lum.paper,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: lum.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Active sessions',
          style: AppTypography.title3.copyWith(color: lum.textPrimary),
        ),
      ),
      body: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: AppInlineBanner(
              message: e.toString(),
              type: BannerType.error,
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: lum.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadius.clay),
                      ),
                      child: Icon(
                        Icons.devices_outlined,
                        size: 34,
                        color: lum.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      'No active sessions.',
                      style: AppTypography.subhead.copyWith(
                        color: lum.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.base,
            ),
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final s = sessions[i];
              final users = s['users'] as Map<String, dynamic>?;
              final name = users?['full_name'] as String? ??
                  users?['email'] as String? ??
                  'Unknown';
              final status = s['status'] as String? ?? 'active';
              final lastActive = s['last_active_at'] as String?;
              final deviceId = s['device_id'] as String?;
              final isRevoked = status == 'REVOKED';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < sessions.length - 1 ? AppSpacing.md : 0,
                ),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Avatar(
                            initial: name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            revoked: isRevoked,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTypography.headline.copyWith(
                                    color: lum.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (deviceId != null) ...[
                                      Flexible(
                                        child: Text(
                                          deviceId,
                                          style: AppTypography.footnote.copyWith(
                                            color: lum.textTertiary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '  ·  ',
                                        style: AppTypography.footnote.copyWith(
                                          color: lum.textTertiary,
                                        ),
                                      ),
                                    ],
                                    Text(
                                      _relativeTime(lastActive),
                                      style: AppTypography.monoValue.copyWith(
                                        color: lum.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusPill(revoked: isRevoked),
                        ],
                      ),
                      if (!isRevoked) ...[
                        const SizedBox(height: AppSpacing.base),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            label: 'Sign out',
                            icon: Icons.logout,
                            variant: AppButtonVariant.destructive,
                            loading: _revokingId == s['user_id'],
                            onPressed: _revokingId != null
                                ? null
                                : () => _revoke(s['user_id'] as String),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Rounded clay-tinted initial badge for a session's user.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.revoked});

  final String initial;
  final bool revoked;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final bg = revoked ? lum.dangerSoft : lum.accentSoft;
    final fg = revoked ? lum.dangerText : lum.accent;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.title3.copyWith(color: fg, fontSize: 18),
      ),
    );
  }
}

/// Lumen-toned status pill: live sessions read as "Active", revoked as "Revoked".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.revoked});

  final bool revoked;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final bg = revoked ? lum.g200 : lum.accentSoft;
    final fg = revoked ? lum.textTertiary : lum.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!revoked) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            revoked ? 'Revoked' : 'Active',
            style: AppTypography.caption.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
