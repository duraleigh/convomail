"""Launch the pymap IMAP test server on Windows.

pymap calls loop.add_signal_handler(), which asyncio does not implement on
Windows. This wrapper stubs it so the server starts; Ctrl+C / process kill
still stop it. Usage (from the repo root):

    python tool/pymap_win.py --port 1143 --no-tls dict --demo-data

Demo credentials: demouser / demopass.
"""
import asyncio
import sys

from pymap.main import main

asyncio.BaseEventLoop.add_signal_handler = lambda self, *args, **kwargs: None  # type: ignore[method-assign]

if __name__ == "__main__":
    sys.exit(main())
