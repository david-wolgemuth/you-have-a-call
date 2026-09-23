#!/bin/sh
# Creates the self-signed certificate build.sh signs with, so calendar permission survives rebuilds.
set -eu
name="You Have a Call Local Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$keychain" | grep -q "\"$name\""; then
    echo "certificate \"$name\" already exists"
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

# Homebrew's OpenSSL 3 writes a .p12 that `security import` rejects, so we use the system LibreSSL.
/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
    -subj "/CN=$name" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false"
/usr/bin/openssl pkcs12 -export -out id.p12 -inkey key.pem -in cert.pem -passout pass:tmp -name "$name"
security import id.p12 -k "$keychain" -P tmp -T /usr/bin/codesign

echo "Enter your Mac login password so codesign can use the key without a prompt on every build."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -l "$name" "$keychain" >/dev/null
echo "created certificate \"$name\""
