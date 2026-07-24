import 'package:flutter/foundation.dart';

/// On-device speech_to_text works here (live partials, no network).
bool get voiceSearchNativeSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Desktop platforms speech_to_text can't do — voice there goes through the
/// cloud STT path (record + transcribe Edge Function). Phase 2.
bool get voiceSearchCloudSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Any voice-search path is available on this platform.
bool get voiceSearchSupported =>
    voiceSearchNativeSupported || voiceSearchCloudSupported;
