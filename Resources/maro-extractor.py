"""Private bounded line protocol. Stdout is protocol-only; never log source URLs."""
import contextlib
import json
import os
import re
import sys
import signal
import threading
import time

import yt_dlp
from yt_dlp.globals import plugin_dirs

plugin_dirs.value = []
MAX_OUTPUT = 8 * 1024 * 1024


class QuietLogger:
    def debug(self, message):
        pass

    warning = debug
    error = debug


def classify(error):
    text = str(error).lower()
    for code, fragments in [
        ("accessRestricted", ["sign in", "sign-in", "not a bot", "age-restricted", "members-only", "private video"]),
        ("network", ["timed out", "temporary failure", "unable to resolve", "connection refused", "network is unreachable", "certificate verify failed", "http error 429", "http error 403"]),
        ("videoUnavailable", ["video unavailable", "video has been removed", "not available in your country"]),
        ("runtimeUnavailable", ["no supported javascript runtime", "javascript runtime is not supported", "unable to find a supported javascript"]),
        ("sourceNeedsUpdate", ["signature extraction failed", "nsig extraction failed"]),
    ]:
        if any(fragment in text for fragment in fragments):
            return code
    return "failed"


def extract(request, node):
    operation, value = request["operation"], request["value"]
    if operation == "ping":
        return {"pid": os.getpid()}
    if not isinstance(value, str):
        raise ValueError("Invalid input")
    if operation == "search":
        if not value.strip() or len(value.encode()) > 512 or any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise ValueError("Invalid query")
        url = "ytsearch20:" + value.strip()
    elif operation == "resolve" and re.fullmatch(r"[A-Za-z0-9_-]{11}", value):
        url = "https://www.youtube.com/watch?v=" + value
    else:
        raise ValueError("Invalid operation")
    # Fresh options/YoutubeDL per request; imports, interpreter and EJS stay warm.
    options = dict(quiet=True, no_warnings=True, logger=QuietLogger(),
                   cachedir=False, skip_download=True, socket_timeout=15,
                   retries=0, extractor_retries=0, js_runtimes={"node": {"path": node}},
                   remote_components=set(), proxy="", noplaylist=True,
                   extract_flat="in_playlist" if operation == "search" else False,
                   playlistend=20)
    with yt_dlp.YoutubeDL(options) as extractor:
        return extractor.sanitize_info(extractor.extract_info(url, download=False))


def main():
    node = sys.argv[1]
    if not os.path.isabs(node) or not os.access(node, os.X_OK) or os.getpgrp() != os.getpid():
        return 1
    output = sys.stdout
    parent = os.getppid()

    def parent_watchdog():
        # Crash/force-quit protection: EOF alone waits for an in-progress network request.
        while True:
            time.sleep(0.5)
            if os.getppid() != parent:
                os.killpg(os.getpgrp(), signal.SIGKILL)

    threading.Thread(target=parent_watchdog, daemon=True).start()
    # Unexpected library prints cannot corrupt framing or reveal signed URLs.
    with open(os.devnull, "w") as sink, contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        output.write('{"ready":1}\n')
        output.flush()
        while True:
            line = sys.stdin.buffer.readline(4097)
            if not line:
                return 0
            if len(line) > 4096 or not line.endswith(b"\n"):
                return 2
            request_id = None
            try:
                request = json.loads(line)
                request_id = request["id"]
                if not isinstance(request_id, str) or len(request_id) > 64:
                    return 2
                result = {"id": request_id, "result": extract(request, node)}
                encoded = json.dumps(result, ensure_ascii=True, separators=(",", ":"))
                if len(encoded) > MAX_OUTPUT:
                    result = {"id": request_id, "error": "outputLimit"}
                    encoded = json.dumps(result)
            except Exception as error:
                encoded = json.dumps({"id": request_id, "error": classify(error)})
            output.write(encoded + "\n")
            output.flush()


if __name__ == "__main__":
    raise SystemExit(main())
