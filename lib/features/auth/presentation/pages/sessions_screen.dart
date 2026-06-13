import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
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
    setState(() => _revokingId = userId);
    await ref.read(sessionsControllerProvider.notifier).revoke(userId);
    if (mounted) setState(() => _revokingId = null);
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
    final state = ref.watch(sessionsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Active sessions', style: AppTypography.headline),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(message: e.toString(), type: BannerType.error),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 48, color: AppColors.textHint),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No active sessions.',
                      style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
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

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < sessions.length - 1 ? AppSpacing.md : 0,
                ),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: status == 'REVOKED'
                              ? AppColors.destructive.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTypography.headline.copyWith(
                              color: status == 'REVOKED'
                                  ? AppColors.destructive
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppTypography.headline),
                            Text(
                              '${s['device_id'] != null ? '${s['device_id']} · ' : ''}${_relativeTime(lastActive)}',
                              style: AppTypography.footnote.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != 'REVOKED')
                        AppButton(
                          label: 'Sign out',
                          variant: AppButtonVariant.destructive,
                          loading: _revokingId == s['user_id'],
                          onPressed: _revokingId != null
                              ? null
                              : () => _revoke(s['user_id'] as String),
                        ),
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
