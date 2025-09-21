#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

cd "${WORK_DIR}" || exit

# === Settings (overridable via ENV) ===
REUSEPORT="${REUSEPORT:-target/debug/reuseport}"  # binary to run
PORT="${PORT:-3000}"                  # listen port
REQUESTS="${REQUESTS:-128}"            # number of HTTP requests
CURL_TIMEOUT="${CURL_TIMEOUT:-2}"     # curl timeout (seconds)
HOST="${HOST:-127.0.0.1}"             # target host
INSTANCES="${INSTANCES:-8}"           # number of processes to start
 # Cleanup on exit
PIDS=()
cleanup() {
  if [ "${#PIDS[@]}" -gt 0 ]; then
    echo "==> Killing instances..."
    kill "${PIDS[@]}" 2>/dev/null || true
    wait 2>/dev/null || true
  fi
}
trap cleanup EXIT

# 1) Build or skip
if [ "${SKIP_BUILD:-}" = "1" ]; then
  echo "==> SKIP_BUILD=1; skipping cargo build"
  if [ ! -x "$REUSEPORT" ]; then
    echo "ERROR: REUSEPORT binary not found or not executable at: $REUSEPORT" >&2
    exit 1
  fi
else
  echo "==> Building project (cargo build)..."
  cargo build || { echo "Cargo build failed!"; exit 1; }
fi

# 2) Start multiple instances
echo "==> Starting $INSTANCES instances on :$PORT"
for i in $(seq 1 "$INSTANCES"); do
  RUST_LOG=info "$REUSEPORT" > /dev/null 2>&1 &
  pid=$!
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Failed to start instance $i"
    exit 1
  fi
  PIDS+=("$pid")
done
echo "==> PIDs: ${PIDS[*]}"

# 3) Wait for listeners (use lsof only)
echo -n "==> Waiting for listener(s) on :$PORT "
for t in {1..30}; do
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "OK"
    echo "==> Listeners (PID/COMMAND):"
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN | awk 'NR==1{next}{printf "INSTANCE:\t%s\t%s\n", $2, $1}' | sort -u
    break
  fi
  sleep 0.2
  if [ "$t" -eq 30 ]; then
    echo "TIMEOUT waiting for listeners"
    exit 1
  fi
done

# 3b) Verify listener count equals INSTANCES
if command -v lsof >/dev/null 2>&1; then
  LIST_PIDS=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -Fp | sed -n 's/^p//p' | sort -u)
else
  echo "ERROR: lsof is not available to verify listeners." >&2
  exit 1
fi
LIST_COUNT=$(printf "%s\n" "$LIST_PIDS" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$LIST_COUNT" -ne "$INSTANCES" ]; then
  echo "ERROR: Expected $INSTANCES listening instances, but found $LIST_COUNT:" >&2
  printf '  %s\n' $LIST_PIDS >&2
  exit 1
fi


FETCHED_PIDS=()
# 4) /pid requests (sequential, keep-alive disabled, summary)
fetch_pid() {
  pid="$(curl -sS --http1.0 --no-keepalive --max-time "$CURL_TIMEOUT" "$URL" 2>/dev/null)"
  printf "RESPONSE:\t%s\n" "$pid"
  FETCHED_PIDS+=("$pid")
}
URL="http://$HOST:$PORT/pid"
echo "==> Sending $REQUESTS sequential requests (no keep-alive) to $URL"


for i in $(seq 1 "$REQUESTS"); do
  fetch_pid   # & yok
done

echo "==> Summary (count per PID):"
printf "%s\n" "${FETCHED_PIDS[@]}" | sort | uniq -c | sort -nr | awk '{print "SUM:\t"$2"\t"$1}'
echo "==> Summary End"
echo "Total: ${#FETCHED_PIDS[@]} (expected $REQUESTS)"
echo "Done"
