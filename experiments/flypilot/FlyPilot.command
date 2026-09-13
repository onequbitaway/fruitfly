#!/bin/bash
set -euo pipefail
flypilot_root="$(cd "$(dirname "$0")" && pwd)"
cd "$flypilot_root"
exec ./flypilot.sh run
