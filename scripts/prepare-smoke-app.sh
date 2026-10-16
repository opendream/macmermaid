#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="$PWD/build/MacMermaid.app"
test_app="$PWD/build/MacMermaid Smoke.app"
ditto "$source_app" "$test_app"
plutil -replace CFBundleIdentifier -string app.macmermaid.SmokeTest "$test_app/Contents/Info.plist"
plutil -replace CFBundleName -string 'MacMermaid Smoke' "$test_app/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string 'MacMermaid Smoke' "$test_app/Contents/Info.plist"
plutil -replace CFBundleDocumentTypes.0.LSHandlerRank -string None "$test_app/Contents/Info.plist"
plutil -insert MacMermaidSmokeDirectory -string "$PWD/build/smoke" "$test_app/Contents/Info.plist"
codesign --force --deep --sign - "$test_app"
printf 'Prepared %s\n' "$test_app"
