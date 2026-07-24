import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/widgets/app_button.dart';
import '../design/widgets/app_inline_banner.dart';
import '../design/widgets/app_sheet.dart';
import '../services/scanner_support.dart';

const _manualEntrySentinel = '__BARCODE_SCAN_MANUAL__';
const _noCodeFoundSentinel = '__BARCODE_NO_CODE__';

/// Returned by [scanBarcodeFromImage] when the picked image had no readable
/// barcode/QR (distinct from null = the user cancelled the picker).
const barcodeNoCodeFoundSentinel = _noCodeFoundSentinel;

/// Let the user pick an image (file/gallery) and decode a barcode/QR from it.
/// This is the scan path on desktop, where live camera scanning is unavailable.
/// Returns the decoded value, [barcodeNoCodeFoundSentinel] if none was found,
/// or null if the user cancelled or the picker was refused.
Future<String?> scanBarcodeFromImage() async {
  FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(type: FileType.image);
  } on PlatformException {
    return null;
  }
  if (result == null || result.files.isEmpty) return null;
  final path = result.files.first.path;
  if (path == null) return null;

  // mobile_scanner (full formats) where it has a plugin; pure-Dart zxing2
  // QR decode on Windows/Linux where it does not.
  final code = mobileScannerAnalyzeImageSupported
      ? await _decodeViaMobileScanner(path)
      : await _decodeQrPureDart(path);
  return (code == null || code.isEmpty) ? _noCodeFoundSentinel : code;
}

Future<String?> _decodeViaMobileScanner(String path) async {
  final controller = MobileScannerController();
  try {
    final capture = await controller.analyzeImage(path);
    final barcode = capture?.barcodes.firstOrNull;
    return barcode?.rawValue ?? barcode?.displayValue;
  } on Exception {
    return null;
  } finally {
    await controller.dispose();
  }
}

/// Pure-Dart QR decode for platforms without a mobile_scanner plugin
/// (Windows/Linux). Reads QR/DataMatrix only, not 1D barcodes.
Future<String?> _decodeQrPureDart(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final pixels = Int32List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        pixels[y * image.width + x] = (0xFF << 24) |
            (p.r.toInt() << 16) |
            (p.g.toInt() << 8) |
            p.b.toInt();
      }
    }
    final bitmap = BinaryBitmap(
      HybridBinarizer(RGBLuminanceSource(image.width, image.height, pixels)),
    );
    return QRCodeReader().decode(bitmap).text;
  } on Exception {
    return null; // NotFoundException et al.
  }
}

/// Unified product-scan entry point used by Products, POS and Dashboard.
/// Offers a camera/image chooser where both are supported (mobile), goes
/// straight to the camera on camera-only, or the image picker on desktop
/// (macOS). Returns the decoded code, [barcodeNoCodeFoundSentinel] when an
/// image had no readable code, or null on cancel / unsupported.
Future<String?> scanProductCode(
  BuildContext context, {
  String title = 'Scan Product',
}) async {
  final hasCamera = barcodeScanSupported;
  final hasImage = barcodeImageScanSupported;
  if (!hasCamera && !hasImage) return null;

  String source;
  if (hasCamera && hasImage) {
    final choice = await showAppSheet<String>(
      context: context,
      builder: (_) => const _ScanSourceSheet(),
    );
    if (choice == null) return null;
    source = choice;
  } else {
    source = hasCamera ? 'camera' : 'image';
  }

  if (source == 'image') return scanBarcodeFromImage();

  if (!context.mounted) return null;
  final code = await scanBarcode(context, title: title);
  if (code == null || code == _manualEntrySentinel) return null;
  return code;
}

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

class _ScanSourceSheet extends StatelessWidget {
  const _ScanSourceSheet();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text('Scan product',
              style: AppTypography.title3.copyWith(color: lum.textPrimary)),
        ),
        _row(context, lum, LucideIcons.camera, 'Use camera', 'camera'),
        const SizedBox(height: 8),
        _row(context, lum, LucideIcons.image, 'From an image', 'image'),
      ],
    );
  }

  Widget _row(BuildContext context, LumColors lum, IconData icon, String label,
      String value) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: lum.accent),
            const SizedBox(width: 14),
            Text(label,
                style: AppTypography.body.copyWith(color: lum.textPrimary)),
          ],
        ),
      ),
    );
  }
}
