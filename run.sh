#!/usr/bin/env bash
# Run the WU game in Godot.
# Usage:
#   ./run.sh              # launch the game normally
#   ./run.sh --test       # run headless tests
#   ./run.sh --import     # headless incremental import
#   ./run.sh --reimport   # wipe .godot/imported cache + full headless reimport
#   ./run.sh --measure-anchors  # regenerate Hu anchors from sprite pixels
#   ./run.sh --anchor-sanity    # validate stored Hu anchors against sprite pixels
#   ./run.sh --scale-masters <dir>     # normalize smooth masters to a common canvas
#   ./run.sh --probe-reach             # derive Hu authored reach and enemy range targets
#   ./run.sh --probe-light-deadzone    # sweep point-blank Hu light geometry
#   ./run.sh --snapshot-reach <out.json> # save machine-readable Hu reach data
#   ./run.sh --stage-held-keyframes <dir> # stage approved held keyframes as smooth masters
#   ./run.sh --shot-combat [dir] # save deterministic combat screenshots, then quit
#   ./run.sh --shot-archetype=<id> [dir] # save deterministic combat + enemy archetype screenshots
#   ./run.sh --shot-action STATE [dir] # save every rendered frame for one combat state
#   ./run.sh --playtest --seed N [--out file.json] # run one deterministic headless autoplay
#   ./run.sh --playtest-batch --seeds 1..20 [--out file.json] # run a deterministic autoplay batch
#   ./run.sh --playtest-daemon --session ID # run an agent-clocked interactive session
#   ./run.sh --capture spec.json [dir_or_png] # capture a JSON-described visual state
#   ./run.sh --install-video <run-dir> --action=<name> --frames=... [--prefix=va] # install staged video frames
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
	        "$GODOT" --path "$PROJECT_DIR" --headless --import 2> >(grep -vF 'ERROR: Condition "ret != noErr" is true. Returning: ""' >&2)
	        exit $?
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
	        "$GODOT" --path "$PROJECT_DIR" --headless --import 2> >(grep -vF 'ERROR: Condition "ret != noErr" is true. Returning: ""' >&2)
	        exit $?
        ;;
    --measure-anchors)
        echo "Measuring sprite anchors -> hu.manifest.json..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/measure_anchors.gd
        ;;
    --anchor-sanity)
        echo "Validating stored sprite anchors..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/anchor_sanity.gd
        ;;
    --scale-masters)
        shift
        echo "Scaling smooth masters..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/scale_masters.gd -- "$@"
        ;;
    --probe-reach)
        echo "Probing Hu authored reach..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/probe_hu_reach.gd
        ;;
    --probe-light-deadzone)
        echo "Probing Hu light point-blank geometry..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/probe_light_deadzone.gd
        ;;
    --snapshot-reach)
        OUT="${2:?usage: ./run.sh --snapshot-reach <out.json>}"
        echo "Snapshotting Hu reach -> $OUT"
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/snapshot_hu_reach.gd -- "--out=$OUT"
        ;;
    --stage-held-keyframes)
        shift
        echo "Staging held keyframes..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/stage_held_keyframes.gd -- "$@"
        ;;
    --install-video)
        shift
        echo "Installing video frames..."
        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://tools/install_video_frames.gd -- "$@"
        ;;
    --shot-combat)
        SHOT_DIR="${2:-/tmp/wu-shot-combat}"
        echo "Capturing combat screenshots -> $SHOT_DIR"
        exec "$GODOT" --path "$PROJECT_DIR" -- --shot-combat "--shot-dir=$SHOT_DIR"
        ;;
    --shot-action)
        STATE="${2:?usage: ./run.sh --shot-action STATE [dir]}"
        SHOT_DIR="${3:-/tmp/wu-shot-action}"
        echo "Capturing action frames for $STATE -> $SHOT_DIR"
        exec "$GODOT" --path "$PROJECT_DIR" -- --shot-action "--shot-state=$STATE" "--shot-dir=$SHOT_DIR"
        ;;
	    --shot-archetype=*)
	        ARCHETYPE="${1#--shot-archetype=}"
	        SHOT_DIR="${2:-/tmp/wu-balance-$ARCHETYPE}"
	        echo "Capturing combat screenshots for $ARCHETYPE -> $SHOT_DIR"
	        exec "$GODOT" --path "$PROJECT_DIR" -- --shot-combat "--shot-archetype=$ARCHETYPE" "--shot-dir=$SHOT_DIR"
	        ;;
	    --playtest|--playtest-batch)
	        echo "Running deterministic playtest..."
	        exec "$GODOT" --path "$PROJECT_DIR" --headless --script res://scripts/sim/playtest_main.gd -- "$@"
	        ;;
	    --playtest-daemon)
	        shift
	        echo "Running interactive playtest daemon..."
	        exec "$GODOT" --path "$PROJECT_DIR" --script res://scripts/sim/playtest_daemon_main.gd -- "$@"
	        ;;
	    --capture)
	        SPEC="${2:?usage: ./run.sh --capture spec.json [out_dir_or_png]}"
	        OUT="${3:-/tmp/wu-capture}"
	        if [ "$OUT" = "--out" ]; then
	            OUT="${4:?usage: ./run.sh --capture spec.json [out_dir_or_png]}"
	        fi
	        echo "Capturing visual state -> $OUT"
	        exec "$GODOT" --path "$PROJECT_DIR" -- --capture "--capture-spec=$SPEC" "--shot-dir=$OUT"
	        ;;
    --editor|-e)
        echo "Opening Godot editor..."
        exec "$GODOT" --path "$PROJECT_DIR" --editor
        ;;
    --help|-h)
	        sed -n '2,20p' "$0"
        ;;
    "")
        echo "Launching WU..."
        exec "$GODOT" --path "$PROJECT_DIR"
        ;;
    *)
        echo "Unknown option: $1" >&2
	        echo "Usage: $0 [--test|--import|--reimport|--measure-anchors|--anchor-sanity|--scale-masters <dir>|--install-video <args>|--probe-reach|--probe-light-deadzone|--snapshot-reach <out.json>|--stage-held-keyframes <dir>|--shot-combat|--shot-action STATE|--shot-archetype=<id>|--playtest|--playtest-batch|--playtest-daemon --session ID|--capture spec.json [out_dir_or_png]|--editor|--help]" >&2
        exit 1
        ;;
esac
