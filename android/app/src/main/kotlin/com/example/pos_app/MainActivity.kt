package com.example.pos_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity): local_auth_android attaches the
// biometric prompt via androidx.fragment.app.FragmentActivity and throws
// uiUnavailable ("current Activity must be a FragmentActivity") otherwise.
class MainActivity : FlutterFragmentActivity()
