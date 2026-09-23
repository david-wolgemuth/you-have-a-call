#!/bin/sh
# Installs the built app to ~/Applications and starts it at login through a LaunchAgent.
# ./install.sh --uninstall stops it and removes both.
set -eu
cd "$(dirname "$0")"

label=com.davidwolgemuth.you-have-a-call
dest="$HOME/Applications/You Have a Call.app"
plist="$HOME/Library/LaunchAgents/$label.plist"
job="gui/$(id -u)/$label"

stop() {
    launchctl bootout "$job" 2>/dev/null || true
    # bootout returns before the job is fully gone, and bootstrap fails until it is.
    while launchctl print "$job" >/dev/null 2>&1; do sleep 0.2; done
    pkill -x YouHaveACall 2>/dev/null || true
}

if [ "${1:-}" = "--uninstall" ]; then
    stop
    rm -f "$plist"
    rm -rf "$dest"
    echo "uninstalled"
    exit 0
fi

[ -d "build/You Have a Call.app" ] || ./build.sh
stop
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$dest"
ditto "build/You Have a Call.app" "$dest"

cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$dest/Contents/MacOS/YouHaveACall</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <!-- Restart after a crash, but stay stopped after Quit from the menu. -->
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/you-have-a-call.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/you-have-a-call.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$plist"
echo "installed $dest and started $label"
