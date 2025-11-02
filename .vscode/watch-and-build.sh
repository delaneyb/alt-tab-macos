#!/bin/zsh

# Enable strict error checking after sourcing config files
set -u

# Kill any orphaned watchexec processes first. When VS Code tasks terminate, watchexec
# can get reparented to init (PID 1) and continue running in the background. Without
# this cleanup, multiple watchexec instances accumulate, each triggering builds and
# spawning AltTab instances, causing mysterious Signal(15) kills and multiple
# simultaneous builds.
pkill -f 'watchexec.*build-and-launch\.sh' 2>/dev/null || true
# Give processes a moment to terminate
sleep 0.1

# Watch for Swift file changes in src/ and rebuild/relaunch on change
watchexec \
  --restart \
  --exts swift \
  --watch src \
  --debounce 250 \
  --print-events \
  -- \
  "${0%/*}/build-and-launch.sh"

