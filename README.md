# You Have a Call

A small background macOS app that interrupts you when a video meeting starts.
At the start time it opens a window above your other windows, takes focus, and a random `say` voice repeats "<meeting title> has started" every 8 seconds until you dismiss it.

It reads events from macOS Calendar through EventKit, so Apple handles the Google sync. There is no Google sign-in, no polling of an API, and no LLM.

## What alerts

An event alerts when all of these hold:

- It is on a calendar listed in `watchedCalendars`.
- It is not all-day.
- You have not declined it.
- It has a Meet or Zoom link in its URL, location, or notes. Set `onlyVideoMeetings = false` to alert for every timed event.

The colored bar shows your response: green for accepted, orange for not answered yet, yellow for maybe, and blue for events with no invite.

If the app starts, or the Mac wakes, up to 5 minutes after a meeting began, it still alerts.

## Buttons

- **Dismiss** (Return or Esc) closes the alert.
- **Snooze 1 min** closes it and shows it again 60 seconds later.

Neither button changes your calendar. EventKit can read your response to an invite but cannot set it.

## Menu bar

A phone icon in the menu bar shows the next meeting that will alert, and has these items:

- **Pause for 1 hour** and **Pause until tomorrow** (midnight). The icon changes to a hung-up phone while paused. A meeting that starts during a pause is skipped. If the pause ends less than 5 minutes after a meeting started, that meeting still alerts. The pause survives a restart.
- **Resume**, shown only while paused.
- **Test alert now** shows the alert for the next meeting.
- **Quit You Have a Call** stops the app until the next login.

## Build, install, and run

Requirements: the Xcode Command Line Tools (`xcode-select --install`). Xcode itself is not needed.

```sh
./build.sh      # compiles and signs build/You Have a Call.app
./install.sh    # copies it to ~/Applications, starts it now and at every login
```

Run both after every change. `install.sh` restarts the running copy.

`install.sh` writes a LaunchAgent to `~/Library/LaunchAgents/com.davidwolgemuth.you-have-a-call.plist`.
`launchd` restarts the app about 10 seconds after a crash, but not after Quit from the menu.
The app's output goes to `~/Library/Logs/you-have-a-call.log`.

| To | Run |
|---|---|
| Start it again after Quit | `open ~/Applications/"You Have a Call.app"` |
| Stop it and remove it from login | `./install.sh --uninstall` |
| Print today's events, with ALERT or the reason each is skipped | `./list.sh` |

The first launch asks for full calendar access.
The first install also shows a macOS "Background Items Added" notification. The app then appears in System Settings > General > Login Items & Extensions.

## Code layout

| File | Contents |
|---|---|
| `app/Settings.swift` | The constants you are likely to change |
| `app/Events.swift` | Which events alert, video link detection, response status |
| `app/Speech.swift` | Voice list, `say`, and title cleanup for speech |
| `app/CallWindow.swift` | The alert window and its buttons |
| `app/AppDelegate.swift` | Calendar access, the 10-second check, the menu bar icon |
| `app/main.swift` | Starts the app |

## Settings

Settings are constants in `app/Settings.swift`. Change one, then run `./build.sh && ./install.sh`.

| Constant | Default | Meaning |
|---|---|---|
| `watchedCalendars` | `["david.wolgemuth@turquoise.health"]` | Calendar titles to watch, as shown in Calendar.app |
| `onlyVideoMeetings` | `true` | Skip events without a Meet or Zoom link |
| `repeatEvery` | `8` seconds | Gap between repeats of the voice |
| `lateStartGrace` | `5` minutes | How late a start can be and still alert |

## Code signing

macOS files the calendar permission under the app's code signature.
An ad-hoc signature (`codesign --sign -`) changes on every build, which makes macOS ask for calendar access again after each rebuild.
`build.sh` signs with a self-signed certificate named `You Have a Call Local Signing` in the login keychain instead, so the permission survives rebuilds.

One-time setup on a new Mac:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
  -subj "/CN=You Have a Call Local Signing" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -out id.p12 -inkey key.pem -in cert.pem -passout pass:tmp \
  -name "You Have a Call Local Signing"
security import id.p12 -k ~/Library/Keychains/login.keychain-db -P tmp -T /usr/bin/codesign
rm key.pem cert.pem id.p12

# Lets codesign use the key without a keychain prompt on every build. Asks for your login password.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -l "You Have a Call Local Signing" ~/Library/Keychains/login.keychain-db
```

Use `/usr/bin/openssl` (LibreSSL). Homebrew's OpenSSL 3 writes a `.p12` format that `security import` rejects unless you add `-legacy`.

## Not done yet

- Two meetings that start together open two windows, and both voices talk at once.
- The Zoom link pattern has not been tested against a real Zoom invite.

See `docs/design-options.md` for the approaches considered and why this one won.
