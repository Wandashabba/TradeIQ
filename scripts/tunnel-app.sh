#!/usr/bin/env bash
#
# One command to expose the local backend over a cloudflared quick tunnel AND
# point the phone app at it.
#
# Why this exists: quick tunnels (cloudflared tunnel --url ...) mint a NEW
# random *.trycloudflare.com URL on EVERY start. The Flutter app bakes that URL
# in at build time (--dart-define=API_BASE_URL), so every tunnel restart leaves
# the installed app calling a dead URL — the app just shows "Something went
# wrong" until it's rebuilt against the new URL. This script captures the URL
# cloudflared prints and rebuilds+installs the app automatically, so the two
# never drift.
#
# Prereqs:
#   - backend running:   (cd backend && npm run dev:safe)
#   - a device attached:  flutter devices
#   - cloudflared and flutter on PATH
#
# Usage:
#   scripts/tunnel-app.sh [device-id]
#
# Leave the terminal open afterwards — it IS the tunnel. Ctrl-C stops it.
#
set -uo pipefail

PORT="${PORT:-4000}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO/app"
DEVICE="${1:-}"
LOG="$(mktemp -t tunnel-app)"

cleanup() {
  echo
  echo "[tunnel-app] stopping tunnel"
  [ -n "${CF_PID:-}" ] && kill "$CF_PID" 2>/dev/null
  rm -f "$LOG"
}
trap 'cleanup; exit 0' INT TERM

# 0. Sanity: is the backend actually up? (non-fatal — warn and continue.)
if ! curl -sf -m 3 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
  echo "[tunnel-app] WARNING: backend not responding on :${PORT}."
  echo "[tunnel-app]          start it first:  (cd backend && npm run dev:safe)"
fi

# 1. Start the tunnel and capture the URL it prints.
echo "[tunnel-app] starting cloudflared -> http://localhost:${PORT}"
cloudflared tunnel --url "http://localhost:${PORT}" >"$LOG" 2>&1 &
CF_PID=$!

URL=""
for _ in $(seq 1 30); do
  URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -1)"
  [ -n "$URL" ] && break
  kill -0 "$CF_PID" 2>/dev/null || { echo "[tunnel-app] cloudflared exited early:"; cat "$LOG"; exit 1; }
  sleep 1
done
if [ -z "$URL" ]; then
  echo "[tunnel-app] could not read the tunnel URL from cloudflared output:"
  cat "$LOG"
  cleanup
  exit 1
fi
echo "[tunnel-app] tunnel URL: ${URL}"

# 2. Build + install the app against that URL.
echo "[tunnel-app] building + installing the app against ${URL} (a couple of minutes)…"
DEV_ARGS=()
[ -n "$DEVICE" ] && DEV_ARGS=(-d "$DEVICE")
if ! ( cd "$APP_DIR" \
       && flutter build apk --debug --dart-define=API_BASE_URL="$URL" \
       && flutter install --debug "${DEV_ARGS[@]}" ); then
  echo "[tunnel-app] build/install failed — see output above."
  cleanup
  exit 1
fi

echo
echo "[tunnel-app] ✅ app installed and pointed at ${URL}"
echo "[tunnel-app] Leave THIS terminal open — it is the tunnel. Ctrl-C stops it."
wait "$CF_PID"
