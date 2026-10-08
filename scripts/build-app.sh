#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
sdk_path="$(xcrun --show-sdk-path)"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    sdk_path=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
mkdir -p .build/module-cache .build/user-cache .build/cache
export SDKROOT="$sdk_path"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export XDG_CACHE_HOME="$PWD/.build/user-cache"
swift build --disable-sandbox --cache-path .build/cache --manifest-cache local --sdk "$sdk_path" -debug-info-format none -c release --product TalkType

app_path="${PWD}/dist/TalkType.app"
mkdir -p "${app_path}/Contents/MacOS"
mkdir -p "${app_path}/Contents/Resources"
mkdir -p "${app_path}/Contents/Frameworks"
cp .build/release/TalkType "${app_path}/Contents/MacOS/TalkType"
cp Resources/Info.plist "${app_path}/Contents/Info.plist"
cp Resources/AppIcon.icns "${app_path}/Contents/Resources/AppIcon.icns"
cp Resources/Sounds/*.wav "${app_path}/Contents/Resources/"
sparkle_framework="${PWD}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    print -u2 "Sparkle framework was not resolved by Swift Package Manager."
    exit 1
fi
rm -rf "${app_path}/Contents/Frameworks/Sparkle.framework"
ditto "$sparkle_framework" "${app_path}/Contents/Frameworks/Sparkle.framework"
if [[ -n "${TALKTYPE_UPDATE_FEED_URL:-}" ]]; then
    plutil -insert SUFeedURL -string "$TALKTYPE_UPDATE_FEED_URL" "${app_path}/Contents/Info.plist"
fi
./scripts/setup-signing.sh
signing_dir="${PWD}/.signing"
keychain_path="${signing_dir}/TalkType.keychain-db"
password="$(cat "${signing_dir}/keychain-password")"
security unlock-keychain -p "$password" "$keychain_path"
codesign --force --deep --sign "TalkType Local Code Signing" --keychain "$keychain_path" "${app_path}/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "TalkType Local Code Signing" --keychain "$keychain_path" "$app_path"
security lock-keychain "$keychain_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
print "Built ${app_path}"
