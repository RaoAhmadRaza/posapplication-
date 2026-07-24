# Build the Voxa STT sidecar (voxa.exe) + pre-download model weights, then stage
# them beside the Flutter Windows app so it auto-launches Voxa offline.
#
# Run on a WINDOWS machine with Python 3.9+ installed (PyInstaller cannot
# cross-compile a Windows exe from macOS/Linux).
#
#   1) Extract the Voxa source (VOXA-main.zip) somewhere, e.g. tools\voxa\VOXA-main
#   2) From the repo root:
#        powershell -ExecutionPolicy Bypass -File tools\voxa\build_windows.ps1 `
#          -VoxaSrc tools\voxa\VOXA-main -Model base
#   3) flutter build windows        (then bundle the staged voxa\ folder — see README)
#
# Output: <RunnerRelease>\voxa\voxa.exe  and  <RunnerRelease>\voxa\models\  (HF cache)

param(
  [Parameter(Mandatory = $true)] [string] $VoxaSrc,
  [string] $Model = "base",
  [string] $OutDir = "build\windows\x64\runner\Release\voxa"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$VoxaSrc = (Resolve-Path $VoxaSrc).Path

Write-Host "==> venv + deps"
$venv = Join-Path $here ".buildvenv"
if (-not (Test-Path $venv)) { python -m venv $venv }
$py = Join-Path $venv "Scripts\python.exe"
& $py -m pip install --upgrade pip
& $py -m pip install -r (Join-Path $VoxaSrc "requirements.txt")
& $py -m pip install pyinstaller
& $py -m pip install $VoxaSrc     # make `voxa` importable

Write-Host "==> pre-download model '$Model' into staged HF cache"
$modelsDir = Join-Path $OutDir "models"
New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null
$env:HF_HOME = (Resolve-Path $modelsDir).Path
& $py -c "from voxa.core import Transcriber; Transcriber('$Model', device='cpu', compute_type='int8'); print('model cached')"

Write-Host "==> pyinstaller"
Push-Location $here
try {
  & $py -m PyInstaller --noconfirm --clean voxa.spec
} finally {
  Pop-Location
}

Write-Host "==> stage voxa.exe -> $OutDir"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item (Join-Path $here "dist\voxa.exe") (Join-Path $OutDir "voxa.exe") -Force

Write-Host "DONE. Bundled: $OutDir\voxa.exe + $OutDir\models\"
Write-Host "Verify: run the app, then curl http://127.0.0.1:8000/health"
