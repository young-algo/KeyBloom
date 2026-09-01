#!/bin/zsh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$repo_dir/docs/showcase}"
source "$repo_dir/scripts/swift_env.sh"

cd "$repo_dir"
swift build -c release
mkdir -p "$output_dir"
KEYBLOOM_SNAPSHOT_DIR="$output_dir" .build/release/KeyBloom
