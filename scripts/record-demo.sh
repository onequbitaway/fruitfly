#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
demo_bin="$(swift build -c release --show-bin-path)/Fruitfly"
demo_output="$(pwd)/.cache/activity-export"
"$demo_bin" --record-activity "$demo_output" "$(pwd)"
mkdir -p docs/media
cp "$demo_output/brain-activity.gif" "$demo_output/brain-activity.png" \
   "$demo_output/activity-frames.json" "$demo_output/activity-manifest.json" docs/media/
gzip -n -c "$demo_output/cell-activity.f32" > docs/media/cell-activity.f32.gz
./scripts/check-demo.sh
