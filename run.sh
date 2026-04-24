#!/usr/bin/env bash
# Run the WU game in Godot.
# Usage:
#   ./run.sh              # launch the game normally
#   ./run.sh --test       # run headless tests
#   ./run.sh --import     # headless incremental import
#   ./run.sh --reimport   # wipe .godot/imported cache + full headless reimport
#   ./run.sh --editor     # open the Godot editor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/WUGodot"

# Use a dedicated HOME so Godot's settings don't pollute the user profile
export HOME="${WU_GODOT_HOME:-/tmp/godot-home}"
mkdir -p "$HOME"

# Find godot binary
if command -v godot >/dev/null 2>&1; then
    GODOT="godot"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
    echo "Error: godot binary not found. Install Godot 4.6.2+ or add it to PATH." >&2
    exit 1
fi

case "${1:-}" in
    --test|-t)
        echo "Running headless tests..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tests/run_tests.gd
        ;;
    --import|-i)
        echo "Running headless import..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --import
        ;;
    --reimport|-r)
        CACHE="$PROJECT_DIR/.godot/imported"
        if [ -d "$CACHE" ]; then
            echo "Wiping import cache: $CACHE"
            rm -rf "$CACHE"
        else
            echo "No import cache to wipe ($CACHE)"
        fi
        # First pass rebuilds the cache. During startup Godot scans resources
        # before import completes, so any resource whose dependencies haven't
        # been re-imported yet (e.g. theme.tres -> font.otf) prints a
        # transient error. We suppress that noise and rely on the second pass
        # to verify a clean load.
        echo "Reimport pass 1/2 (populating cache)..."
        "$GODOT" --path "$PROJECT_DIR" --headless --import 2>/dev/null >/dev/null
        echo "Reimport pass 2/2 (verifying clean load)..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --import
        ;;
    --editor|-e)
        echo "Opening Godot editor..."
        exec "$GODOT" --path "$PROJECT_DIR" --editor
        ;;
    --help|-h)
        sed -n '2,8p' "$0"
        ;;
    "")
        echo "Launching WU..."
        exec "$GODOT" --path "$PROJECT_DIR"
        ;;
    *)
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [--test|--import|--reimport|--editor|--help]" >&2
        exit 1
        ;;
esac
