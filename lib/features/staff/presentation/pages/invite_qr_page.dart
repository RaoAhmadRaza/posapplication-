import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../domain/entities/staff_entities.dart';

/// Shows the invite QR + raw token ONCE. The token is never persisted or
/// refetchable — it only exists in the [CreatedInvite] passed via `extra`.
class InviteQrPage extends StatelessWidget {
  const InviteQrPage({super.key, required this.inviteId, this.invite});

  final String inviteId;
  final CreatedInvite? invite;

  @override
  Widget build(BuildContext context) {
    final inv = invite;
    return AppDetailScaffold(
      eyebrow: 'Invites',
      title: inv == null ? 'Code unavailable' : 'Invite ready',
      maxContentWidth: 560,
      child: inv == null ? _expired(context) : _qr(context, inv),
    );
  }

  Widget _expired(BuildContext context) => AppEmptyState(
        icon: LucideIcons.eyeOff,
        title: 'This code was shown once',
        body: "For safety we don't store the code after it's revealed. It's no "
            'longer available here — regenerate a fresh one from the invite.',
        action: AppButton(
          label: 'Back to invites',
          variant: AppButtonVariant.tinted,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );

  Widget _qr(BuildContext context, CreatedInvite inv) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInlineBanner(
          message: 'Shown only once. If you leave this screen you\'ll need to '
              'regenerate it — nothing is lost, just re-issued.',
          type: BannerType.error,
        ),
        const SizedBox(height: 20),
        ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // QR stays on white in every theme so scanners read it.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: QrImageView(
                  data: inv.qrPayload,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Have your teammate open the LUMINA app → "Join with QR", '
                'or share the code below.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(color: lum.g500, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text('Expires ${_fmtExpiry(inv.expiresAt)}',
                  style: AppTypography.caption.copyWith(color: lum.g400)),
            ],
          ),
        ),
        const SizedBox(height: 20),
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

class _TokenRow extends StatefulWidget {
  const _TokenRow({required this.token});
  final String token;

  @override
  State<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends State<_TokenRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.token));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite code',
            style: AppTypography.label.copyWith(color: lum.g700)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: SelectableText(
            widget.token,
            style: AppTypography.monoValue.copyWith(color: lum.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: _copied ? 'Code copied' : 'Copy code',
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          icon: _copied ? LucideIcons.check : LucideIcons.copy,
          onPressed: _copy,
        ),
      ],
    );
  }
}
