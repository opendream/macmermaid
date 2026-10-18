#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
python3 scripts/check-licenses.py
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
build_flags=(-c "$configuration")
if [ "$configuration" = release ]; then
  build_flags+=(-debug-info-format none)
fi
swift build --disable-sandbox --cache-path "$PWD/.build/cache" "${build_flags[@]}"
binary_dir="$(swift build --disable-sandbox --cache-path "$PWD/.build/cache" -c "$configuration" --show-bin-path)"
app="$PWD/build/MacMermaid.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MacMermaid" "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/third-party"
cp third-party/manifest.json third-party/audit-v12.json "$app/Contents/Resources/third-party/"
ditto "$binary_dir/MacMermaid_MacMermaid.bundle" "$app/Contents/Resources/MacMermaid_MacMermaid.bundle"
if [ ! -f build/AppIcon.icns ] || [ scripts/icon.swift -nt build/AppIcon.icns ] || [ scripts/package-icon.py -nt build/AppIcon.icns ]; then
  mkdir -p build/AppIcon.iconset
  swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" scripts/icon.swift "$PWD/build/AppIcon.iconset"
  python3 scripts/package-icon.py
fi
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
python3 scripts/check-licenses.py --app "$app"
codesign --force --deep --sign - "$app"
printf 'Built %s\n' "$app"
