#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="build/You Have a Call.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp app/Info.plist "$app/Contents/Info.plist"
swiftc -O app/main.swift -o "$app/Contents/MacOS/YouHaveACall"
codesign --force --sign "You Have a Call Local Signing" "$app"
echo "built $app"
