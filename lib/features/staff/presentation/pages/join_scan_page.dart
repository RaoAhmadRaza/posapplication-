import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
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
    context.push('/join/redeem',
        extra: (token: token, validation: validation));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Scan invite', style: AppTypography.headline),
        actions: [
          TextButton(
            onPressed: () => setState(() => _manual = !_manual),
            child: Text(_manual ? 'Scan' : 'Enter code'),
          ),
        ],
      ),
      body: SafeArea(
        child: _manual ? _manualEntry() : _scanner(),
      ),
    );
  }

  Widget _scanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Text(
            _error ?? 'Point your camera at the invite QR code.',
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(
                color: _error != null ? AppColors.destructive : AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _manualEntry() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text('Enter the invite code your admin gave you.',
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _manualCtrl,
          label: 'Invite code',
          prefixIcon: Icons.vpn_key_outlined,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!,
              style: AppTypography.footnote.copyWith(color: AppColors.destructive)),
        ],
        const SizedBox(height: AppSpacing.lg),
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
