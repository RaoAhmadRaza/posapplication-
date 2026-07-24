import 'package:flutter/foundation.dart';

bool get barcodeScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Decoding a barcode/QR from a still image (picked from files/gallery) is the
/// scan path on desktop, where live camera scanning is unavailable. Available on
/// every native platform: mobile_scanner's analyzeImage on iOS/Android/macOS,
/// and a pure-Dart zxing2 QR decode on Windows/Linux (where mobile_scanner has
/// no plugin). Note: the zxing2 fallback reads QR/DataMatrix only, not 1D codes.
bool get barcodeImageScanSupported => !kIsWeb;

/// True where mobile_scanner's analyzeImage is available (full format support).
/// Elsewhere (Windows/Linux) the image path falls back to a pure-Dart QR decode.
bool get mobileScannerAnalyzeImageSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);
