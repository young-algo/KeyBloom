#!/bin/zsh

# This Mac can have a newer Command Line Tools compiler paired with a mismatched
# default beta SDK. KeyBloom targets macOS 14, so prefer the compatible 15.4 SDK
# when it is present and no SDK was explicitly selected by the caller.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

cache_base="${TMPDIR:-/tmp}/keybloom-module-cache"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$cache_base/clang}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$cache_base/swiftpm}"
