import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/widgets/app_button.dart';

/// Opens a modal signature pad. Returns the captured signature as PNG bytes,
/// or null if the user cancelled or drew nothing.
Future<Uint8List?> captureSignature(BuildContext context) {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SignaturePadDialog(),
  );
}

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog();

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  bool _exporting = false;

  bool get _hasInk => _strokes.any((s) => s.length > 1);

  void _start(Offset p) => setState(() => _strokes.add([p]));
  void _extend(Offset p) => setState(() => _strokes.last.add(p));

  void _clear() => setState(_strokes.clear);

  Future<void> _confirm() async {
    if (!_hasInk) return;
    setState(() => _exporting = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      title: const Text('Customer Signature'),
      content: SizedBox(
        // Bounded so the pad reads well on desktop windows and phones alike.
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign inside the box.', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.separator),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: GestureDetector(
                    onPanStart: (d) => _start(d.localPosition),
                    onPanUpdate: (d) => _extend(d.localPosition),
                    child: CustomPaint(
                      painter: _SignaturePainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _exporting || !_hasInk ? null : _clear,
          child: const Text('Clear'),
        ),
        AppButton(
          label: 'Use Signature',
          onPressed: _exporting || !_hasInk ? null : _confirm,
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    // Opaque white ground so the exported PNG is not transparent.
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final ink = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], ink);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
