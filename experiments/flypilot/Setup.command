#!/bin/bash
set -euo pipefail
flypilot_root="$(cd "$(dirname "$0")" && pwd)"
cd "$flypilot_root"
./setup.sh
read -r -p "Press Return to close this window."
