#!/usr/bin/env bash
# One-command launcher: starts the Python vision sidecar, then the Godot game
# fullscreen, and shuts the sidecar down when the game exits.
#
# Run it as:   ./run.sh        (do NOT 'source' it)
#
# Overridable via environment variables:
#   GODOT_BIN  path to the Godot binary           (default: $HOME/dev/Godot_v4.7-stable_linux.x86_64)
#   VENV       path to a Python venv to activate   (default: ./ai_dance_game)
#   WEIGHTS    YOLO weights/engine for the sidecar (default: weights/yolov8m-pose.pt)
#              On a Jetson, export a TensorRT engine and point this at the .engine.

# If this file is sourced instead of executed, bail out without touching the
# interactive shell — sourcing a launcher that exits/errors is what closes your
# terminal. (No `set -e`, no top-level `exit`, for the same reason.)
if [ "${BASH_SOURCE[0]:-$0}" != "${0}" ]; then
	echo "Run it as ./run.sh — don't 'source' this script." >&2
	return 1 2>/dev/null || exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$HERE" || { echo "Cannot cd to $HERE" >&2; exit 1; }

GODOT_BIN="${GODOT_BIN:-$HOME/dev/tools/Godot_v4.7-stable_linux.x86_64}"
VENV="${VENV:-$HERE/ai_dance_game}"
WEIGHTS="${WEIGHTS:-weights/yolov8m-pose.pt}"

if [ -f "$VENV/bin/activate" ]; then
	# shellcheck disable=SC1091
	source "$VENV/bin/activate"
fi

# Accept either a command on PATH or an executable file path.
if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
	echo "Godot binary not found or not executable: $GODOT_BIN" >&2
	echo "Set it with:  GODOT_BIN=/path/to/godot ./run.sh   (and chmod +x it)" >&2
	exit 1
fi

echo "Starting vision service (weights: $WEIGHTS)…"
python -m ai_camera_server.vision_service --weights "$WEIGHTS" &
VISION_PID=$!

cleanup() {
	kill "$VISION_PID" 2>/dev/null || true
	wait "$VISION_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Launching game…"
"$GODOT_BIN" --path "$HERE" -- --fullscreen
