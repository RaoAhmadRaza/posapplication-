import 'package:flutter/foundation.dart';

bool get barcodeScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
