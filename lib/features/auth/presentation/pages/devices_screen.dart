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
import '../../domain/entities/device.dart';
import '../controllers/devices_controller.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'settings',
      action: 'update',
      child: const _DevicesContent(),
    );
  }
}

class _DevicesContent extends ConsumerStatefulWidget {
  const _DevicesContent();

  @override
  ConsumerState<_DevicesContent> createState() => _DevicesContentState();
}

class _DevicesContentState extends ConsumerState<_DevicesContent> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(devicesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final state = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: lum.paper,
      appBar: AppBar(
        backgroundColor: lum.paper,
        surfaceTintColor: lum.paper,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: lum.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Devices',
          style: AppTypography.title3.copyWith(color: lum.textPrimary),
        ),
      ),
      body: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppInlineBanner(
                  message: 'Unable to load devices.',
                  type: BannerType.error,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.read(devicesProvider.notifier).load(),
                ),
              ],
            ),
          ),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.devices, size: 48, color: lum.textTertiary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No devices registered.',
                      style: AppTypography.subhead
                          .copyWith(color: lum.textSecondary),
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
            itemCount: devices.length,
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(
                bottom: i < devices.length - 1 ? AppSpacing.md : 0,
              ),
              child: _DeviceCard(device: devices[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.device});
  final Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lum.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Icon(_deviceIcon, color: lum.accent, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style:
                          AppTypography.headline.copyWith(color: lum.textPrimary),
                    ),
                    Text(
                      '${device.osInfo} · ${device.deviceModel}',
                      style: AppTypography.footnote
                          .copyWith(color: lum.textSecondary),
                    ),
                  ],
                ),
              ),
              _TrustBadge(trustLevel: device.trustLevel),
            ],
          ),
          if (device.lastSeenAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  'Last seen',
                  style:
                      AppTypography.caption.copyWith(color: lum.textTertiary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatDate(device.lastSeenAt),
                  style:
                      AppTypography.monoValue.copyWith(color: lum.textSecondary),
                ),
              ],
            ),
          ],
          Divider(color: lum.hairline, height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!device.authorized)
                AppButton(
                  label: 'Approve',
                  variant: AppButtonVariant.tinted,
                  onPressed: () =>
                      ref.read(devicesProvider.notifier).approve(device.id),
                ),
              if (!device.authorized) const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Revoke',
                variant: AppButtonVariant.destructive,
                onPressed: () async {
                  final ok = await showAppConfirm(
                    context,
                    title: 'Revoke this device?',
                    message: 'It will be signed out and must be re-authorized '
                        'to access this account.',
                    confirmLabel: 'Revoke',
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref.read(devicesProvider.notifier).revoke(device.id);
                  if (!context.mounted) return;
                  showAppToast(
                    context,
                    'Device revoked',
                    type: BannerType.success,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _deviceIcon {
    final os = device.osInfo.toLowerCase();
    if (os.contains('ios') || os.contains('iphone')) return Icons.phone_iphone;
    if (os.contains('macos')) return Icons.laptop_mac;
    if (os.contains('android')) return Icons.phone_android;
    if (os.contains('windows')) return Icons.laptop_windows;
    return Icons.devices;
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.trustLevel});
  final String trustLevel;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (bg, fg, label) = switch (trustLevel) {
      'TRUSTED' => (lum.successSoft, lum.successText, 'Trusted'),
      'REVOKED' => (lum.dangerSoft, lum.dangerText, 'Revoked'),
      _ => (lum.warningSoft, lum.warningText, 'Pending'),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
