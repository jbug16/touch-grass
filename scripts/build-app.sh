#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"

app="$root/build/Touch Grass.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/TouchGrass" "$app/Contents/MacOS/TouchGrass"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
chmod +x "$app/Contents/MacOS/TouchGrass"
codesign --force --sign - "$app"

echo "Built $app"
