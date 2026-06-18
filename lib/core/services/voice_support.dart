import 'package:flutter/foundation.dart';

bool get voiceSearchSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
