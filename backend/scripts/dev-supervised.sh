#!/usr/bin/env bash
#
# Dev backend with a health watchdog.
#
# `ts-node-dev --respawn` recompiles on file changes, but it can wedge in a
# non-serving state: if a transient TypeScript error is caught mid-change
# (e.g. the working tree is briefly inconsistent during a `git checkout` or
# branch switch), the compile fails, the server never binds :PORT, and
# --respawn only tries again on the NEXT file change — which may never come.
# The process stays alive but dead to requests, so the app just sees
# "Something went wrong" until someone restarts it by hand.
#
# This supervisor polls /health and force-restarts the dev server when it
# stops responding, so the backend heals itself. Use it in place of
# `npm run dev`:  `npm run dev:safe`
#
set -uo pipefail
cd "$(dirname "$0")/.."  # run from backend/

PORT="${PORT:-4000}"
HEALTH_URL="http://localhost:${PORT}/health"
FAIL_LIMIT=3        # consecutive failed checks before a restart
CHECK_INTERVAL=5    # seconds between checks
BOOT_GRACE=25       # seconds to allow first boot / a recompile before counting

kill_dev() { pkill -f "ts-node-dev.*src/server.ts" 2>/dev/null; }
start_dev() { echo "[watchdog] launching: npm run dev"; npm run dev & }

trap 'echo; echo "[watchdog] stopping"; kill_dev; exit 0' INT TERM

kill_dev            # clear any stragglers from a previous run
sleep 1
start_dev
sleep "$BOOT_GRACE"

fails=0
while true; do
  if curl -sf -m 3 "$HEALTH_URL" >/dev/null 2>&1; then
    (( fails > 0 )) && echo "[watchdog] /health recovered"
    fails=0
  else
    fails=$((fails + 1))
    echo "[watchdog] /health unreachable (${fails}/${FAIL_LIMIT})"
    if (( fails >= FAIL_LIMIT )); then
      echo "[watchdog] backend not responding — restarting"
      kill_dev
      sleep 2
      start_dev
      sleep "$BOOT_GRACE"
      fails=0
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
