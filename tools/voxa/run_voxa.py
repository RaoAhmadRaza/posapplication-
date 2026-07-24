"""PyInstaller entry point for the bundled Voxa sidecar.

Boots the same uvicorn server as `python -m voxa.server`, honouring
VOXA_HOST / VOXA_PORT / VOXA_MODEL / VOXA_DEVICE / VOXA_COMPUTE_TYPE. The
Flutter app sets these (and HF_HOME for the bundled weights) when it launches
voxa.exe.
"""

from voxa.server import main

if __name__ == "__main__":
    main()
