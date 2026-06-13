import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityLogsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Security logs', style: AppTypography.headline),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    Icon(Icons.history, size: 48, color: AppColors.textHint),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No security activity yet.',
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
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final log = logs[i];
              final action = log['action'] as String? ?? '';
              final entity = log['entity'] as String? ?? '';
              final time = log['created_at'] as String?;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_icon(action), color: AppColors.textMuted, size: 22),
                title: Text(
                  action.replaceAll('_', ' ').toLowerCase().capitalize(),
                  style: AppTypography.subhead,
                ),
                subtitle: Text(
                  '${entity.capitalize()} · ${_relativeTime(time)}',
                  style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                ),
                dense: true,
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
