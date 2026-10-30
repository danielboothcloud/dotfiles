"""Persistent single-digit labels for the shared Zellij session picker."""

import fcntl
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

DIGITS = (1, 2, 3, 4, 5, 6, 7, 8, 9, 0)


def numbered_sessions(listing, state_path):
    """Keep exited sessions in order; close numbering gaps after deletion."""
    sessions = {}
    for line in listing.splitlines():
        name, separator, metadata = line.rpartition(" [Created ")
        if separator:
            sessions[name] = "(EXITED" not in metadata

    state_path.parent.mkdir(parents=True, exist_ok=True)
    with state_path.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            saved = json.loads(state_path.read_text())
        except FileNotFoundError:
            saved = {}
        if not isinstance(saved, dict) or any(
            not isinstance(name, str) or type(digit) is not int or digit not in DIGITS
            for name, digit in saved.items()
        ) or len(set(saved.values())) != len(saved):
            raise ValueError(f"Invalid session labels in {state_path}; refusing to renumber")

        ordered = sorted(
            (name for name in saved if name in sessions),
            key=lambda name: DIGITS.index(saved[name]),
        )
        ordered.extend(name for name in sessions if name not in saved)
        labels = dict(zip(ordered, DIGITS, strict=False))

        # Atomic replacement plus a separate lock protects simultaneous pickers.
        if labels != saved or not state_path.exists():
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(
                    mode="w", dir=state_path.parent, delete=False
                ) as output:
                    temporary = output.name
                    json.dump(labels, output, indent=2)
                    output.write("\n")
                os.replace(temporary, state_path)
            finally:
                if temporary and os.path.exists(temporary):
                    os.unlink(temporary)

    active = [name for name, alive in sessions.items() if alive]
    active.sort(key=lambda name: DIGITS.index(labels[name]) if name in labels else 10)
    return [f"{labels.get(name, '-')}\t{name}" for name in active]


def main():
    result = subprocess.run(
        ["zellij", "list-sessions", "--no-formatting"],
        capture_output=True, text=True,
    )
    if result.returncode and "No active zellij sessions" not in result.stdout + result.stderr:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Cannot list sessions")
    root = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    state_path = root / "zellij/session-picker-ids.json"
    for row in numbered_sessions(result.stdout, state_path):
        print(row)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f"Session picker: {error}", file=sys.stderr)
        sys.exit(1)
