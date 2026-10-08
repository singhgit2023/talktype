#!/bin/zsh
set -euo pipefail
umask 077
cd "${0:A:h:h}"
signing_dir="${PWD}/.signing"
keychain_path="${signing_dir}/TalkType.keychain-db"
password_path="${signing_dir}/keychain-password"
mkdir -p "$signing_dir"
if [[ -f "$keychain_path" && -f "$password_path" ]]; then
    print "Using existing TalkType signing identity."
    exit 0
fi

password="$(openssl rand -hex 24)"
print -rn -- "$password" > "$password_path"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 \
    -subj '/CN=TalkType Local Code Signing/O=TalkType' \
    -addext 'keyUsage=critical,digitalSignature' \
    -addext 'extendedKeyUsage=codeSigning' \
    -keyout "$work_dir/private.pem" -out "$work_dir/certificate.pem" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$work_dir/private.pem" \
    -in "$work_dir/certificate.pem" -out "$work_dir/identity.p12" \
    -passout "pass:$password" >/dev/null 2>&1
security create-keychain -p "$password" "$keychain_path"
security unlock-keychain -p "$password" "$keychain_path"
security import "$work_dir/identity.p12" -k "$keychain_path" -P "$password" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain_path" >/dev/null
security lock-keychain "$keychain_path"
print "Created a persistent local signing certificate in ${keychain_path}."
