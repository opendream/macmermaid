#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node --test Tests/Web/*.test.cjs
python3 -m unittest discover -s Tests/Release -v
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift test --disable-sandbox --cache-path "$PWD/.build/cache"
