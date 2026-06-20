#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_bridge_port="${PRINT_BRIDGE_PORT:-19100}"
print_bridge_host="127.0.0.1"
print_bridge_url="${PRINT_BRIDGE_BASE_URL:-http://127.0.0.1:${print_bridge_port}}"
web_port="${WEB_PORT:-3000}"
print_bridge_log="${PRINT_BRIDGE_LOG:-/tmp/wburger-pos-print-bridge.log}"
web_mode_args=()

if [[ "${WBURGER_POS_WEB_WASM:-1}" != "0" ]]; then
  web_mode_args+=(--wasm)
fi

bridge_is_up() {
  python3 - "$print_bridge_host" "$print_bridge_port" <<'PY'
import json
import sys
import urllib.request

host = sys.argv[1]
port = int(sys.argv[2])
try:
    with urllib.request.urlopen(f"http://{host}:{port}/health", timeout=0.6) as res:
        payload = json.loads(res.read().decode("utf-8"))
except Exception:
    sys.exit(1)

if payload.get("message") != "W Burger local print bridge is running.":
    sys.exit(1)
PY
}

if [[ "${WBURGER_START_PRINT_BRIDGE:-1}" != "0" ]]; then
  if bridge_is_up; then
    echo "[wburger-pos] using existing local print bridge at $print_bridge_url"
  else
    nohup python3 "$script_dir/local_print_bridge.py" \
      --host "$print_bridge_host" \
      --port "$print_bridge_port" \
      >"$print_bridge_log" 2>&1 &
    print_bridge_pid="$!"

    for _ in {1..25}; do
      if bridge_is_up; then
        break
      fi
      sleep 0.1
    done

    if ! bridge_is_up; then
      echo "[wburger-pos] local print bridge failed to start on $print_bridge_url" >&2
      echo "[wburger-pos] bridge log: $print_bridge_log" >&2
      exit 1
    fi

    echo "[wburger-pos] started local print bridge pid=$print_bridge_pid"
    echo "[wburger-pos] bridge log: $print_bridge_log"
  fi
fi

echo "[wburger-pos] API: https://w-burger.com"
echo "[wburger-pos] Web: http://localhost:$web_port"
echo "[wburger-pos] Print bridge: $print_bridge_url"
if ((${#web_mode_args[@]})); then
  echo "[wburger-pos] Web mode: wasm/skwasm"
else
  echo "[wburger-pos] Web mode: default canvaskit"
fi

flutter run \
  -d chrome \
  "${web_mode_args[@]}" \
  --web-hostname localhost \
  --web-port "$web_port" \
  --dart-define=API_BASE_URL=https://w-burger.com \
  --dart-define=PRINT_BRIDGE_BASE_URL="$print_bridge_url" \
  "$@"
