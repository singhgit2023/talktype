#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
sdk_path="$(xcrun --show-sdk-path)"
mkdir -p .build/module-cache .build/user-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export XDG_CACHE_HOME="$PWD/.build/user-cache"
swift -sdk "$sdk_path" scripts/draw-icon.swift Resources/AppIcon.png

iconset_dir="$(mktemp -d)/TalkType.iconset"
mkdir -p "$iconset_dir"
for points in 16 32 128 256 512; do
    sips -z "$points" "$points" Resources/AppIcon.png --out "$iconset_dir/icon_${points}x${points}.png" >/dev/null
    pixels=$((points * 2))
    sips -z "$pixels" "$pixels" Resources/AppIcon.png --out "$iconset_dir/icon_${points}x${points}@2x.png" >/dev/null
done
python3 scripts/pack-icon.py "$iconset_dir" Resources/AppIcon.icns
rm -rf "${iconset_dir:h}"
