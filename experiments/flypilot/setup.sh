#!/bin/bash
set -euo pipefail
flypilot_root="$(cd "$(dirname "$0")" && pwd)"
cd "$flypilot_root"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo "This setup was tested on Apple Silicon Macs only." >&2
  exit 1
fi
command -v swift >/dev/null || { echo "Install Apple Command Line Tools with xcode-select --install." >&2; exit 1; }
command -v uv >/dev/null || { echo "Install uv. See https://docs.astral.sh/uv/getting-started/installation/." >&2; exit 1; }
uv sync --frozen
.venv/bin/python scripts/fetch-character.py
../full-map/scripts/fetch-data.sh
swift build -c release
echo "FlyPilot is ready. Run ./flypilot.sh run."
