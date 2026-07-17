import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/staff_entities.dart';

/// Shows the invite QR + raw token ONCE. The token is never persisted or
/// refetchable — it only exists in the [CreatedInvite] passed via `extra`.
class InviteQrPage extends StatelessWidget {
  const InviteQrPage({super.key, required this.inviteId, this.invite});

  final String inviteId;
  final CreatedInvite? invite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Staff invite', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: invite == null ? _expired(context) : _qr(context, invite!),
      ),
    );
  }

  Widget _expired(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: AppInlineBanner(
            message:
                'This code is shown only once and is no longer available. Regenerate the invite to get a new one.',
            type: BannerType.info,
          ),
        ),
      );

  Widget _qr(BuildContext context, CreatedInvite inv) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        AppInlineBanner(
          message: 'Shown once — show it to your staff now. Leaving this screen loses it.',
          type: BannerType.error,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.separator, width: 0.5),
            ),
            child: QrImageView(
              data: inv.qrPayload,
              version: QrVersions.auto,
              size: 260,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text('Expires ${_fmtExpiry(inv.expiresAt)}',
              style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TokenRow(token: inv.token),
      ],
    );
  }

  String _fmtExpiry(DateTime at) {
    final d = at.difference(DateTime.now());
    if (d.inHours >= 24) return 'in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return 'in ${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return 'soon';
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Or enter this code manually:',
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        SelectableText(token,
            style: AppTypography.body.copyWith(fontFamily: 'monospace')),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Copy code',
          variant: AppButtonVariant.tinted,
          icon: Icons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: token));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Code copied.')));
            }
          },
        ),
      ],
    );
  }
}
