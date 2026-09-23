#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="build/You Have a Call.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp app/Info.plist "$app/Contents/Info.plist"
swiftc -O app/*.swift -o "$app/Contents/MacOS/YouHaveACall"
identity="You Have a Call Local Signing"
if security find-identity -p codesigning | grep -q "\"$identity\""; then
    codesign --force --sign "$identity" "$app"
else
    codesign --force --sign - "$app"
    echo "no signing certificate; calendar access will re-prompt after each rebuild (run ./setup-signing.sh to fix)"
fi
echo "built $app"
