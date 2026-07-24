import 'package:flutter/foundation.dart';

bool get barcodeScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Decoding a barcode/QR from a still image (picked from files/gallery) is the
/// scan path on desktop, where live camera scanning is unavailable. Supported
/// wherever mobile_scanner's analyzeImage works: iOS, Android and macOS.
bool get barcodeImageScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);
