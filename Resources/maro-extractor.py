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
PAGE_SIZE = 25
MAX_RESULTS = 500
search_sessions = {}


def close_search(query):
    session = search_sessions.pop(query, None)
    if session:
        session["extractor"].close()


def search_page(value, options):
    request = json.loads(value)
    query, offset = request.get("query"), request.get("offset", 0)
    if (not isinstance(query, str) or not query.strip() or len(query.encode()) > 512
            or any(ord(c) < 32 or ord(c) == 127 for c in query)
            or type(offset) is not int or not 0 <= offset < MAX_RESULTS):
        raise ValueError("Invalid query")
    query = query.strip()
    session = search_sessions.get(query)
    # Offsets make continuations reconstructable if playback preempts the worker.
    if session and session["offset"] != offset:
        close_search(query)
        session = None
    if not session:
        if len(search_sessions) >= 8:
            close_search(next(iter(search_sessions)))
        extractor = yt_dlp.YoutubeDL(options)
        try:
            # Do not sanitize/materialize the playlist generator: yt-dlp lazily
            # follows YouTube's continuation tokens as entries are consumed.
            info = extractor.extract_info("ytsearch500:" + query, download=False, process=False)
            session = {"extractor": extractor, "entries": iter(info["entries"]), "offset": 0, "seen": set()}
            search_sessions[query] = session
            for _ in range(offset):
                try:
                    skipped = next(session["entries"])
                except StopIteration:
                    close_search(query)
                    return {"entries": [], "continuation": None}
                if isinstance(skipped, dict) and isinstance(skipped.get("id"), str):
                    session["seen"].add(skipped["id"])
                session["offset"] += 1
        except Exception:
            extractor.close()
            search_sessions.pop(query, None)
            raise
    entries = []
    exhausted = False
    try:
        # Fill 25 usable tracks, with a strict scanning budget for malformed or
        # duplicate source records. The cursor counts consumed source records.
        for _ in range(min(PAGE_SIZE * 4, MAX_RESULTS - offset)):
            if len(entries) == PAGE_SIZE:
                break
            try:
                entry = next(session["entries"])
            except StopIteration:
                exhausted = True
                break
            session["offset"] += 1
            if (not isinstance(entry, dict) or not isinstance(entry.get("id"), str)
                    or not re.fullmatch(r"[A-Za-z0-9_-]{11}", entry["id"])
                    or not isinstance(entry.get("title"), str) or not entry["title"].strip()):
                continue
            if entry["id"] in session["seen"]:
                continue
            session["seen"].add(entry["id"])
            entries.append(session["extractor"].sanitize_info(entry))
        continuation = str(session["offset"]) if not exhausted and session["offset"] < MAX_RESULTS and entries else None
        if continuation is None:
            close_search(query)
        return {"entries": entries, "continuation": continuation}
    except Exception:
        close_search(query)
        raise


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
        url = None
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
                   playlistend=MAX_RESULTS if operation == "search" else None)
    if operation == "search":
        return search_page(value, options)
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
