import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../data/repositories/staff_repository_impl.dart';

/// Accepts either the raw token ('lum_...') or the 'lumina://join?t=' QR URL.
String? extractInviteToken(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('lum_')) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri?.scheme == 'lumina' && uri?.host == 'join') {
    return uri!.queryParameters['t'];
  }
  return null;
}

class JoinScanPage extends ConsumerStatefulWidget {
  const JoinScanPage({super.key});

  @override
  ConsumerState<JoinScanPage> createState() => _JoinScanPageState();
}

class _JoinScanPageState extends ConsumerState<JoinScanPage> {
  final _controller = MobileScannerController();
  final _manualCtrl = TextEditingController();
  bool _busy = false;
  bool _manual = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _process(String raw) async {
    if (_busy) return;
    final token = extractInviteToken(raw);
    if (token == null) {
      setState(() => _error = 'That is not a valid invite code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _controller.stop();
    final (validation, failure) =
        await ref.read(staffRepositoryProvider).validateInvite(token);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      await _controller.start();
      return;
    }
    if (validation == null || !validation.valid) {
      setState(() {
        _busy = false;
        _error = validation?.reasonMessage ?? 'This invite code is not valid.';
      });
      await _controller.start();
      return;
    }
    context.push('/join/redeem', extra: (token: token, validation: validation));
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Scaffold(
      backgroundColor: lum.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Scan invite',
                        style: AppTypography.title2
                            .copyWith(fontSize: 22, color: lum.textPrimary)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _manual = !_manual),
                    child: Text(_manual ? 'Scan' : 'Enter code',
                        style: AppTypography.label.copyWith(color: lum.accent)),
                  ),
                ],
              ),
            ),
            Expanded(child: _manual ? _manualEntry(lum) : _scanner(lum)),
          ],
        ),
      ),
    );
  }

  Widget _scanner(LumColors lum) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null) _process(raw);
                    },
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Colors.black45,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Point your camera at the invite QR code.',
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(
                color: _error != null ? lum.dangerText : lum.g500),
          ),
        ],
      ),
    );
  }

  Widget _manualEntry(LumColors lum) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Enter the invite code your admin gave you.',
            style: AppTypography.footnote.copyWith(color: lum.g500)),
        const SizedBox(height: 16),
        AppTextField(
          controller: _manualCtrl,
          label: 'Invite code',
          prefixIcon: Icons.vpn_key_outlined,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: AppTypography.footnote.copyWith(color: lum.dangerText)),
        ],
        const SizedBox(height: 22),
        AppButton(
          label: 'Continue',
          fullWidth: true,
          loading: _busy,
          onPressed: _busy ? null : () => _process(_manualCtrl.text),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.sm,
          isDark: lum.isDark,
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );
  }
}
