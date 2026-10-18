#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="$PWD/build/MacMermaid.app"
test_app="$PWD/build/MacMermaid Smoke.app"
smoke_directory="${1:-$PWD/build/smoke}"
ditto "$source_app" "$test_app"
plutil -replace CFBundleIdentifier -string app.macmermaid.SmokeTest "$test_app/Contents/Info.plist"
plutil -replace CFBundleName -string 'MacMermaid Smoke' "$test_app/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string 'MacMermaid Smoke' "$test_app/Contents/Info.plist"
plutil -replace CFBundleDocumentTypes.0.LSHandlerRank -string None "$test_app/Contents/Info.plist"
plutil -replace MacMermaidSmokeDirectory -string "$smoke_directory" "$test_app/Contents/Info.plist"
codesign --force --deep --sign - "$test_app"
printf 'Prepared %s\n' "$test_app"
