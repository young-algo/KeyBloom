#!/bin/zsh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
display_count="${1:-1}"
duration="${2:-15}"
output_dir="$repo_dir/tmp/profiles"
trace_path="$output_dir/keybloom-${display_count}-display.trace"
source "$repo_dir/scripts/swift_env.sh"

if [[ "$display_count" != "1" && "$display_count" != "2" ]]; then
  echo "Usage: $0 [1|2 displays] [seconds]"
  exit 2
fi

cd "$repo_dir"

if ! xcrun --find xctrace >/dev/null 2>&1; then
  echo "xctrace is unavailable. Install full Xcode, select it with xcode-select, and rerun."
  exit 69
fi

swift build -c release
mkdir -p "$output_dir"
rm -rf "$trace_path"

KEYBLOOM_STRESS=1 \
KEYBLOOM_PROFILE_DISPLAYS="$display_count" \
KEYBLOOM_PROFILE_SECONDS="$duration" \
xcrun xctrace record \
  --template "Time Profiler" \
  --output "$trace_path" \
  --launch -- "$repo_dir/.build/release/KeyBloom"

echo "Trace written to: $trace_path"
