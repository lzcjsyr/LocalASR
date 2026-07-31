#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/LocalASR.app"
SERVER="$APP_BUNDLE/Contents/Resources/bin/whisper-server"
MODEL="$HOME/Library/Application Support/LocalASR/models/ggml-large-v3-turbo-q5_0.bin"
SAMPLE="$ROOT_DIR/vendor/whisper.cpp/samples/jfk.wav"
PORT="18973"
RESPONSE_FILE="$(mktemp -t localasr-pipeline).json"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$RESPONSE_FILE"
}
trap cleanup EXIT

[[ -x "$SERVER" ]] || {
  echo "missing bundled whisper-server; run ./script/build_and_run.sh --verify" >&2
  exit 1
}
[[ -f "$MODEL" ]] || {
  echo "missing downloaded model: $MODEL" >&2
  exit 1
}
[[ -f "$SAMPLE" ]] || {
  echo "missing whisper.cpp sample: $SAMPLE" >&2
  exit 1
}

EXPECTED_SHA1="e050f7970618a659205450ad97eb95a18d69c9ee"
ACTUAL_SHA1="$(shasum -a 1 "$MODEL" | awk '{print $1}')"
[[ "$ACTUAL_SHA1" == "$EXPECTED_SHA1" ]] || {
  echo "model checksum mismatch" >&2
  exit 1
}

"$SERVER" --host 127.0.0.1 --port "$PORT" --model "$MODEL" --language en --threads 6 >/tmp/localasr-server.log 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 120); do
  if curl --fail --silent "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

curl --fail --silent "http://127.0.0.1:$PORT/inference" \
  -F "file=@$SAMPLE" \
  -F "language=en" \
  -F "response_format=verbose_json" >"$RESPONSE_FILE"

jq -e '.text | test("fellow Americans"; "i")' "$RESPONSE_FILE" >/dev/null
jq -e '.segments | length > 0' "$RESPONSE_FILE" >/dev/null
echo "Local ASR pipeline passed: checksum, loopback server, Metal inference, JSON segments"
