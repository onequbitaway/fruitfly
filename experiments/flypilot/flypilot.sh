#!/bin/bash
set -euo pipefail
flypilot_root="$(cd "$(dirname "$0")" && pwd)"
cd "$flypilot_root"
if [[ ! -x .venv/bin/python || ! -x .build/release/FlyBrainService ]]; then
  echo "Run ./setup.sh first." >&2
  exit 1
fi
exec .venv/bin/python -m flypilot "$@"
