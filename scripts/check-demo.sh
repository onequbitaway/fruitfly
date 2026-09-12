#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .cache/check-demo
gzip -dc docs/media/cell-activity.f32.gz > .cache/check-demo/cell-activity.f32
swift run -c release FlyChecks --verify-recording .cache/check-demo/cell-activity.f32 docs/media
