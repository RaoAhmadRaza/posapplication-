# PyInstaller spec for the Voxa STT sidecar (voxa.exe), bundled beside the
# Flutter Windows app. Build via tools/voxa/build_windows.ps1 (runs on Windows).
#
# The heavy native stacks (ctranslate2, onnxruntime, av) need collect_all so
# their DLLs + metadata are pulled in; the Silero VAD asset and the web UI are
# added as data. Model weights are NOT bundled here — they ship separately under
# voxa/models and are loaded at runtime via HF_HOME (see build script).

from PyInstaller.utils.hooks import collect_all, collect_submodules

datas, binaries, hiddenimports = [], [], []

for pkg in ('ctranslate2', 'onnxruntime', 'av', 'tokenizers', 'huggingface_hub'):
    d, b, h = collect_all(pkg)
    datas += d
    binaries += b
    hiddenimports += h

# uvicorn/fastapi lazy imports.
hiddenimports += collect_submodules('uvicorn')
hiddenimports += ['voxa.core', 'voxa.api', 'voxa.server']

# Voxa's own package data: the Silero VAD model and the single-file web UI.
d, b, h = collect_all('voxa')
datas += d
binaries += b
hiddenimports += h

a = Analysis(
    ['run_voxa.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib'],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='voxa',
    debug=False,
    strip=False,
    upx=False,
    console=False,   # no console window — auto-launched by the app
    disable_windowed_traceback=False,
)
