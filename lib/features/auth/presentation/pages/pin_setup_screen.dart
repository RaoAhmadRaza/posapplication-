import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/services/pin_service.dart';
import '../../../../core/widgets/pin_pad.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _errorMessage;
  bool _loading = false;

  void _onFirstComplete(String pin) {
    setState(() {
      _firstPin = pin;
      _errorMessage = null;
    });
  }

  void _onConfirmComplete(String pin) {
    if (pin == _firstPin) {
      _save(pin);
    } else {
      setState(() {
        _firstPin = null;
        _errorMessage = 'PINs do not match. Please try again.';
      });
    }
  }

  Future<void> _save(String pin) async {
    setState(() => _loading = true);
    await PinService.instance.setPin(pin);
    if (mounted) Navigator.of(context).pop();
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
        title: Text('Set PIN', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Text(
                _firstPin == null
                    ? 'Choose a 4-digit PIN for quick login.'
                    : 'Confirm your PIN.',
                style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.base),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: AppInlineBanner(message: _errorMessage!),
              ),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: PinPad(
                        length: 4,
                        onCompleted: _firstPin == null
                            ? _onFirstComplete
                            : _onConfirmComplete,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
