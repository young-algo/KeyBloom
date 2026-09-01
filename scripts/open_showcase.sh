#!/bin/zsh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/swift_env.sh"
cd "$repo_dir"
swift build
KEYBLOOM_SHOWCASE=1 .build/debug/KeyBloom
