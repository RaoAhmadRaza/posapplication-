import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/widgets/app_button.dart';
import '../design/widgets/app_inline_banner.dart';
import '../services/scanner_support.dart';

const _manualEntrySentinel = '__BARCODE_SCAN_MANUAL__';

Future<String?> scanBarcode(
  BuildContext context, {
  String title = 'Scan Barcode',
}) async {
  if (!barcodeScanSupported) return null;
  return Navigator.of(context).push<String?>(
    MaterialPageRoute(builder: (_) => BarcodeScanPage(title: title)),
  );
}

class BarcodeScanPage extends ConsumerStatefulWidget {
  const BarcodeScanPage({super.key, this.title = 'Scan Barcode'});

  final String title;

  static const manualEntrySentinel = _manualEntrySentinel;

  @override
  ConsumerState<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends ConsumerState<BarcodeScanPage> {
  late final MobileScannerController _controller;
  Timer? _debounceTimer;
  bool _hasPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_debounceTimer != null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final code = barcode.rawValue ?? barcode.displayValue;
    if (code == null || code.isEmpty) return;

    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _debounceTimer = null;
    });

    Navigator.of(context).pop(code);
  }

  void _onDetectError(Object error, StackTrace stack) {
    if (error is MobileScannerException &&
        error.errorCode == MobileScannerErrorCode.permissionDenied) {
      setState(() => _hasPermissionDenied = true);
    }
  }

  void _onManualEntry() {
    Navigator.of(context).pop(_manualEntrySentinel);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: AppTypography.headline.copyWith(color: Colors.white),
        ),
      ),
      body: _hasPermissionDenied ? _buildPermissionDenied() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    final scanWindowRect = Rect.fromCenter(
      center: Offset.zero,
      width: 260,
      height: 180,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          onDetectError: _onDetectError,
          fit: BoxFit.cover,
          overlayBuilder: (ctx, constraints) => _buildOverlay(
            constraints,
            scanWindowRect,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.xxxl + 16,
          child: Center(
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) {
                if (state.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                final isOn = state.torchState == TorchState.on;
                return GestureDetector(
                  onTap: _toggleTorch,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isOn
                          ? AppColors.warning.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOn ? Icons.flashlight_on : Icons.flashlight_off,
                      color: isOn ? Colors.black : Colors.white,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          bottom: AppSpacing.xl,
          child: AppButton(
            label: 'Enter Manually',
            variant: AppButtonVariant.plain,
            fullWidth: true,
            onPressed: _onManualEntry,
            icon: Icons.keyboard,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(BoxConstraints constraints, Rect scanWindow) {
    final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

    final centeredRect = Rect.fromCenter(
      center: Offset(canvasSize.width / 2, canvasSize.height / 2),
      width: scanWindow.width * 1.1,
      height: scanWindow.height * 1.1,
    ).inflate(8);

    return Stack(
      children: [
        CustomPaint(
          size: canvasSize,
          painter: _ScanOverlayPainter(
            cutout: centeredRect,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: AppSpacing.xxl,
          child: Text(
            'Point camera at barcode or QR code',
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppInlineBanner(
                message: 'Camera permission needed',
                type: BannerType.error,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Enable camera access in your device settings\nto scan barcodes and serial numbers.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Open Settings',
                variant: AppButtonVariant.filled,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icons.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({required this.cutout, required this.color});

  final Rect cutout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.largest)
      ..addRRect(
        RRect.fromRectAndRadius(
          cutout,
          const Radius.circular(AppRadius.card),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = color);

    final borderPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cutout,
        const Radius.circular(AppRadius.card),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      cutout != oldDelegate.cutout || color != oldDelegate.color;
}
