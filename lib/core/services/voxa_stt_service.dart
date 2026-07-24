import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Windows/Linux voice-search backend: records the mic and transcribes via a
/// locally-running Voxa server (self-hosted speech-to-text — POST /transcribe,
/// GET /health, http://127.0.0.1:8000 by default). speech_to_text has no
/// Windows plugin, so this is the desktop path. Fully offline/local; audio
/// never leaves the machine.
///
/// Configure with --dart-define:
///   VOXA_URL  base URL (default http://127.0.0.1:8000)
///   VOXA_CMD  launch command for the app-managed sidecar (e.g.
///             "python -m voxa.server" or a bundled voxa.exe path). Empty =
///             do not auto-launch; connect only if Voxa is already running.
class VoxaStt {
  VoxaStt._();
  static final VoxaStt instance = VoxaStt._();

  static const _baseUrl =
      String.fromEnvironment('VOXA_URL', defaultValue: 'http://127.0.0.1:8000');
  // Override the launch command; empty = use the bundled voxa exe next to the app.
  static const _launchCmd = String.fromEnvironment('VOXA_CMD');
  static const _model = String.fromEnvironment('VOXA_MODEL', defaultValue: 'base');

  final AudioRecorder _recorder = AudioRecorder();
  Process? _proc;
  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> _healthy() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// exe/args/env for the sidecar: an explicit VOXA_CMD, else the bundled
  /// `<appdir>/voxa/voxa[.exe]`. HF_HOME points at bundled weights so the model
  /// loads offline. Returns null if no launchable target is found.
  ({String exe, List<String> args, Map<String, String> env})? _resolveLaunch() {
    final uri = Uri.parse(_baseUrl);
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final env = <String, String>{
      'VOXA_HOST': uri.host,
      'VOXA_PORT': '${uri.port}',
      'VOXA_MODEL': _model,
    };
    final modelsDir = '$exeDir${sep}voxa${sep}models';
    if (Directory(modelsDir).existsSync()) env['HF_HOME'] = modelsDir;

    if (_launchCmd.trim().isNotEmpty) {
      final parts = _launchCmd.split(' ').where((s) => s.isNotEmpty).toList();
      return (exe: parts.first, args: parts.sublist(1), env: env);
    }
    final exe = '$exeDir${sep}voxa${sep}voxa${Platform.isWindows ? '.exe' : ''}';
    if (!File(exe).existsSync()) return null;
    return (exe: exe, args: const <String>[], env: env);
  }

  /// Reachable already, or launch the bundled/configured sidecar and wait for
  /// health (up to ~20s — first run loads the model). Safe to call repeatedly.
  Future<bool> ensureRunning() async {
    if (await _healthy()) return true;
    if (_proc == null) {
      final launch = _resolveLaunch();
      if (launch == null) return false;
      try {
        _proc = await Process.start(
          launch.exe,
          launch.args,
          environment: launch.env,
          mode: ProcessStartMode.detached,
        );
      } on Exception {
        return false;
      }
    }
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _healthy()) return true;
    }
    return false;
  }

  /// Stop the app-launched sidecar (best effort) — call on app exit.
  void stopServer() {
    _proc?.kill();
    _proc = null;
  }

  /// Begin recording to a temp WAV (16kHz mono — what the engine decodes to).
  /// Returns false if mic permission was denied.
  Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voxa_voice_search.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recording = true;
    return true;
  }

  /// Stop recording and POST the clip to Voxa. Returns the transcript, or null
  /// if nothing was recorded / the server was unreachable / an error occurred.
  Future<String?> stopAndTranscribe() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;
    if (path == null) return null;
    if (!await ensureRunning()) return null;
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transcribe?format=txt'),
      )..files.add(await http.MultipartFile.fromPath('file', path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) return null;
      final text = res.body.trim();
      return text.isEmpty ? null : text;
    } on Exception {
      return null;
    }
  }

  Future<void> cancel() async {
    if (_recording) {
      await _recorder.stop();
      _recording = false;
    }
  }
}
