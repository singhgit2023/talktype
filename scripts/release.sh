#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
./scripts/build-app.sh

app_path="${PWD}/dist/TalkType.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_path}/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${app_path}/Contents/Info.plist")"
feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "${app_path}/Contents/Info.plist")"
[[ "$feed" == 'https://raw.githubusercontent.com/singhgit2023/talktype/main/appcast.xml' ]] || {
    print -u2 "Unexpected Sparkle feed URL: $feed"
    exit 1
}

tools_dir="${PWD}/.build/artifacts/sparkle/Sparkle/bin"
public_key="$("${tools_dir}/generate_keys" --account TalkType-MacLabb -p)"
embedded_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "${app_path}/Contents/Info.plist")"
[[ "$public_key" == "$embedded_key" ]] || {
    print -u2 "The Sparkle Keychain key does not match the public key in the app."
    exit 1
}

if [[ -f appcast.xml ]]; then
    python3 - "$build" <<'PY'
import sys
import xml.etree.ElementTree as ET
ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
versions = [int(node.text) for node in ET.parse('appcast.xml').iter(ns + 'version')]
if versions and int(sys.argv[1]) <= max(versions):
    raise SystemExit('This build is already in appcast.xml. Increase CFBundleVersion before preparing another release.')
PY
fi

staging_dir="$(mktemp -d "${PWD}/dist/sparkle-release.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
archive="TalkType-${version}-macOS-$(uname -m).zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "${staging_dir}/${archive}"
[[ ! -f appcast.xml ]] || cp appcast.xml "$staging_dir/appcast.xml"
notes="docs/release-v${version}.md"
[[ ! -f "$notes" ]] || cp "$notes" "${staging_dir}/${archive%.zip}.md"

"${tools_dir}/generate_appcast" --account TalkType-MacLabb --maximum-deltas 0 \
    --download-url-prefix "https://github.com/singhgit2023/talktype/releases/download/v${version}/" \
    --embed-release-notes "$staging_dir"

cp "${staging_dir}/${archive}" "dist/${archive}"
cp "${staging_dir}/appcast.xml" appcast.xml
(cd dist && shasum -a 256 "$archive" > "TalkType-${version}-SHA256SUMS.txt")
print "Prepared dist/${archive}, checksum, and appcast.xml."
print "Publish the ZIP and checksum in GitHub Release v${version}, then push appcast.xml."
