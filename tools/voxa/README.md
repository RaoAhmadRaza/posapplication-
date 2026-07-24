# Voxa STT sidecar — Windows bundling

The Windows/Linux voice-search path records the mic and POSTs it to a local
[Voxa](https://github.com/RaoAhmadRaza/VOXA) server (`POST /transcribe`,
`GET /health`, `127.0.0.1:8000`). The Flutter app **auto-launches** the bundled
sidecar at startup (`VoxaStt` in `lib/core/services/voxa_stt_service.dart`) and
kills it on exit.

For that to work, `voxa.exe` + the model weights must sit next to the app:

```
<install dir>/
  pos_app.exe
  voxa/
    voxa.exe        # self-contained, built by build_windows.ps1
    models/         # HuggingFace cache (loaded offline via HF_HOME)
```

## Why this isn't prebuilt in the repo

A Windows `.exe` **cannot be cross-compiled from macOS/Linux** — PyInstaller must
run on Windows. So the exe is a build step you run once per Voxa/version bump on a
Windows machine. The repo carries only the build tooling, not the binary/weights.

## Build (on Windows, Python 3.9+)

```powershell
# 1. Extract VOXA-main.zip → tools\voxa\VOXA-main  (git-ignored)
# 2. From the repo root:
powershell -ExecutionPolicy Bypass -File tools\voxa\build_windows.ps1 `
  -VoxaSrc tools\voxa\VOXA-main -Model base
# 3. Build the app:
flutter build windows
```

The script: creates a venv, installs Voxa + PyInstaller, **pre-downloads the model**
into `…\Release\voxa\models`, runs PyInstaller (`voxa.spec` → `voxa.exe`), and stages
`voxa.exe` next to the app. `flutter build windows` must run so the Release runner
dir exists; re-run the script after it if needed (it only touches the `voxa/` folder).

## Installer

Whatever packages the app (Inno Setup / MSIX) must copy the `voxa/` folder next to
`pos_app.exe`. Nothing else to configure.

## Overrides (`--dart-define` on `flutter build windows`)

| define | default | meaning |
|--------|---------|---------|
| `VOXA_URL` | `http://127.0.0.1:8000` | server base URL |
| `VOXA_CMD` | *(empty)* | launch command; empty = bundled `voxa/voxa.exe`. Set to `python -m voxa.server` on dev machines with Python. |
| `VOXA_MODEL` | `base` | model size (`tiny`/`base`/`small`/…) — must match what you pre-downloaded |

## Client machines need no Python

`voxa.exe` is a PyInstaller bundle — it contains the Python interpreter and every
dependency. POS/client machines need **no Python, no pip, no admin** — just the
shipped `voxa/` folder. Python is required only on the build machine, once.

One exception: ctranslate2/onnxruntime link the **Microsoft VC++ Redistributable**
(`msvcp140.dll` etc.). Most Windows PCs already have it; on a clean machine, have
the installer bundle the VC++ redist (or ship the DLLs) or `voxa.exe` won't start.

## Notes

- `voxa.spec` is a **best-effort** starting point — the ctranslate2 / onnxruntime / av
  native stacks are PyInstaller-fiddly; if the exe fails to start, run it from a
  console to see the missing import and add it to `hiddenimports`/`collect_all`.
- CPU + int8 is the default (no GPU needed). `tiny`≈75 MB / `base`≈145 MB weights.
- Not yet verified on a real Windows build — see `docs/DECISIONS.md`.
