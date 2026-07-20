import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/security_logs_controller.dart';

class SecurityLogsScreen extends ConsumerWidget {
  const SecurityLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'settings',
      action: 'read',
      child: const _LogsContent(),
    );
  }
}

class _LogsContent extends ConsumerStatefulWidget {
  const _LogsContent();

  @override
  ConsumerState<_LogsContent> createState() => _LogsContentState();
}

class _LogsContentState extends ConsumerState<_LogsContent> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(securityLogsControllerProvider.notifier).load();
    });
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final local = dt.toLocal();
      return '${_months[local.month - 1]} ${local.day}';
    } catch (_) {
      return iso;
    }
  }

  IconData _icon(String action) {
    return switch (action) {
      'LOGIN' => Icons.login,
      'LOGOUT' => Icons.logout,
      'SIGNUP' => Icons.person_add,
      'PASSWORD_RESET' => Icons.lock_reset,
      'MFA_ENROLL' => Icons.phone_android,
      'DEVICE_APPROVE' => Icons.verified,
      'DEVICE_REVOKE' => Icons.block,
      _ => Icons.history,
    };
  }

  /// Severity → color pair (badge foreground + soft badge background).
  /// Status is never color-only: the row keeps its icon shape + text label.
  (Color, Color) _severity(String action, LumColors lum) {
    return switch (action) {
      'LOGIN' || 'SIGNUP' || 'DEVICE_APPROVE' || 'MFA_ENROLL' => (
          lum.success,
          lum.successSoft,
        ),
      'LOGOUT' || 'PASSWORD_RESET' => (lum.warning, lum.warningSoft),
      'DEVICE_REVOKE' => (lum.danger, lum.dangerSoft),
      _ => (lum.accent, lum.accentSoft),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final state = ref.watch(securityLogsControllerProvider);

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
          'Security logs',
          style: AppTypography.title3.copyWith(color: lum.textPrimary),
        ),
      ),
      body: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineBanner(message: e.toString(), type: BannerType.error),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.read(securityLogsControllerProvider.notifier).load(),
                ),
              ],
            ),
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 48, color: lum.textTertiary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No security activity yet.',
                      style: AppTypography.subhead.copyWith(color: lum.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.base,
            ),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) {
              final log = logs[i];
              final action = log['action'] as String? ?? '';
              final entity = log['entity'] as String? ?? '';
              final time = log['created_at'] as String?;
              final (fg, soft) = _severity(action, lum);
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(_icon(action), color: fg, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.replaceAll('_', ' ').toLowerCase().capitalize(),
                            style: AppTypography.label.copyWith(color: lum.textPrimary),
                          ),
                          if (entity.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              entity.capitalize(),
                              style: AppTypography.footnote
                                  .copyWith(color: lum.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      _relativeTime(time),
                      style: AppTypography.monoValue.copyWith(color: lum.textTertiary),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension _Capitalize on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
