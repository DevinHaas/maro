#!/usr/bin/env python3
"""Opt-in real playback monitor. Records safe state fields; never claims audible quality."""
import argparse
from datetime import datetime, timezone
import json
import signal
from pathlib import Path
import subprocess
import time


def progress(previous, current, wall_seconds):
    """Count only plausible forward media time, never seeks or replay resets."""
    delta = current - previous
    return delta if 0 <= delta <= wall_seconds + 2 else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ctl", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--seconds", type=int, default=1800)
    parser.add_argument("--replay-at-end", action="store_true")
    args = parser.parse_args()
    if not 10 <= args.seconds <= 7200:
        parser.error("Duration must be 10–7200 seconds")
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with args.log.open("x") as log:
        def record(kind, **fields):
            log.write(json.dumps({"time": datetime.now(timezone.utc).isoformat(), "kind": kind, **fields}) + "\n")
            log.flush()

        def command(*arguments):
            result = subprocess.run([str(args.ctl), *arguments], capture_output=True, text=True, timeout=95)
            response = json.loads(result.stdout)
            if not response.get("ok"):
                raise RuntimeError(response.get("error", {}).get("code", "command_failed"))
            return response["snapshot"]

        initial = command("status")
        if not initial.get("loadedVideo") or initial.get("isSelecting"):
            raise RuntimeError("Load a video and finish preparation before starting")
        identity = initial["loadedVideo"]["video"]["id"]
        record("start", videoID=identity, requestedSeconds=args.seconds, initialState=initial["playback"])
        started = time.monotonic()
        previous_time = started
        previous_position = initial["loadedVideo"]["positionSeconds"]
        last_progress = started
        played = 0.0
        replays = 0
        owned_playback = initial["playback"] in ("paused", "ended")
        try:
            signal.signal(signal.SIGTERM, signal.default_int_handler)
            if initial["playback"] == "ended":
                command("replay")
                previous_position = 0
            elif initial["playback"] == "paused":
                command("toggle")
            while played < args.seconds:
                snapshot = command("status")
                now = time.monotonic()
                loaded = snapshot.get("loadedVideo")
                if not loaded or loaded["video"]["id"] != identity:
                    raise RuntimeError("track_changed")
                position = loaded["positionSeconds"]
                delta = progress(previous_position, position, now - previous_time)
                played += delta
                if delta > 0.1:
                    last_progress = now
                record("sample", elapsed=round(now-started, 3), playedSeconds=round(played, 3),
                       position=round(position, 3), state=snapshot["playback"], hasError=bool(snapshot.get("error")))
                if snapshot.get("error") or snapshot.get("sourceNeedsUpdate"):
                    raise RuntimeError("playback_error")
                if snapshot["playback"] == "paused":
                    owned_playback = False  # Respect user pause; do not resume it.
                    raise RuntimeError("paused_during_check")
                if snapshot["playback"] == "ended" and played < args.seconds:
                    if not args.replay_at_end:
                        raise RuntimeError("track_ended_before_target")
                    command("replay")
                    replays += 1
                    record("explicit_probe_replay", count=replays)
                    position = 0
                    last_progress = time.monotonic()
                elif now - last_progress > 45:
                    raise RuntimeError("no_progress_for_45_seconds")
                if now - started > args.seconds + 180:
                    raise RuntimeError("wall_time_budget_exceeded")
                previous_position, previous_time = position, now
                if played < args.seconds:
                    time.sleep(5)
            record("pass", playedSeconds=round(played, 3), elapsed=round(time.monotonic()-started, 3),
                   replays=replays, audibleQualityVerified=False)
            print("PASS: measured real playback progress; audible quality requires human confirmation", flush=True)
        except (Exception, KeyboardInterrupt) as error:
            record("failure", reason="interrupted" if isinstance(error, KeyboardInterrupt) else
                   str(error) if isinstance(error, RuntimeError) else type(error).__name__)
            raise
        finally:
            # Give the bounded cleanup command time to pause our playback.
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            if owned_playback:
                current = command("status")
                if (current.get("loadedVideo") or {}).get("video", {}).get("id") == identity and current["playback"] in ("playing", "buffering"):
                    command("toggle")
                    record("paused_after_check")


if __name__ == "__main__":
    main()
