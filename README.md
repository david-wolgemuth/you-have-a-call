# You Have a Call

A small background macOS app that interrupts you when a video meeting starts.
At the start time it opens a window above your other windows, takes focus, and a random `say` voice repeats "You have a call from <meeting title>" every 8 seconds until you dismiss it.

It reads events from macOS Calendar, so Apple handles the Google sync. There is no Google sign-in, no polling of an API, and no LLM.

## What it does

### Which meetings alert

An event alerts when all of these hold:

- It is on a calendar listed in `watchedCalendars`.
- It is not all-day.
- You have not declined it.
- It has a Meet or Zoom link in its URL, location, or notes. Set `onlyVideoMeetings = false` to alert for every timed event.

If the app starts, or the Mac wakes, up to 5 minutes after a meeting began, it still alerts.

### The alert window

The colored bar shows your response: green for accepted, orange for not answered yet, yellow for maybe, and blue for events with no invite.

- **Dismiss** (Return or Esc) closes the alert.
- **Snooze 1 min** closes it and shows it again 60 seconds later.

Neither button changes your calendar. EventKit can read your response to an invite but cannot set it.

### The menu bar icon

A phone icon in the menu bar shows the next meeting that will alert, and has these items:

- **Pause for 1 hour** and **Pause until tomorrow** (midnight). The icon changes to a hung-up phone while paused. A meeting that starts during a pause is skipped. If the pause ends less than 5 minutes after a meeting started, that meeting still alerts. The pause survives a restart.
- **Resume**, shown only while paused.
- **Test alert now** shows the alert for the next meeting.
- **Quit You Have a Call** stops the app until the next login.

## Set it up

1. **Add your Google account to macOS.** Open System Settings > Internet Accounts > Add Account > Google, sign in, and turn on Calendars.
   If you see `DAAccountValidationDomain / error 100`, wait a minute. The account has finished adding in the background before.
2. **Check the calendar in Calendar.app.** Your events should appear. Note the calendar's title in the sidebar, for example `david.wolgemuth@turquoise.health`.
3. **Set the refresh interval.** In Calendar.app > Settings > Accounts, set Refresh Calendars to "Every 5 minutes". A meeting added later than that interval before its start may not alert.
4. **Point the app at your calendar.** Put the title from step 2 in `watchedCalendars` in `app/Settings.swift`.
5. **Install the Command Line Tools** with `xcode-select --install`. Xcode itself is not needed.
6. **Create the signing certificate** with `./setup-signing.sh`. It asks for your Mac login password once.
7. **Build and install** with `./build.sh && ./install.sh`.
8. **Click Allow** when macOS asks whether "You Have a Call" can have full access to your Calendar. macOS also shows a "Background Items Added" notification, because the app now starts at login.
9. **Check it works.** Run `./list.sh` to see today's events marked `ALERT` or with the reason each is skipped. Then choose **Test alert now** from the menu bar icon.

## Everyday use

| To | Do |
|---|---|
| Stop alerts for a while | Menu bar icon > Pause |
| Start it again after Quit | `open ~/Applications/"You Have a Call.app"` |
| See why a meeting did or did not alert | `./list.sh` |
| Read the app's output | `~/Library/Logs/you-have-a-call.log` |
| Change a setting | Edit `app/Settings.swift`, then `./build.sh && ./install.sh` |
| Remove it and stop it starting at login | `./install.sh --uninstall` |

## Settings

| Constant in `app/Settings.swift` | Default | Meaning |
|---|---|---|
| `watchedCalendars` | `["david.wolgemuth@turquoise.health"]` | Calendar titles to watch, as shown in Calendar.app |
| `onlyVideoMeetings` | `true` | Skip events without a Meet or Zoom link |
| `repeatEvery` | `8` seconds | Gap between repeats of the voice |
| `lateStartGrace` | `5` minutes | How late a start can be and still alert |

## Working on the code

### Code layout

| File | Contents |
|---|---|
| `app/Settings.swift` | The constants you are likely to change |
| `app/Events.swift` | Which events alert, video link detection, response status |
| `app/Speech.swift` | Voice list, `say`, and title cleanup for speech |
| `app/CallWindow.swift` | The alert window and its buttons |
| `app/AppDelegate.swift` | Calendar access, the 10-second check, the menu bar icon |
| `app/main.swift` | Starts the app |
| `app/Info.plist` | Bundle ID and the reason shown in the calendar permission prompt |

`build.sh` compiles every file in `app/` with `swiftc` into `build/You Have a Call.app`, then signs it.
`install.sh` copies that app to `~/Applications` and restarts it, so run both after every change.

### Start at login

`install.sh` writes a LaunchAgent to `~/Library/LaunchAgents/com.davidwolgemuth.you-have-a-call.plist` and loads it with `launchctl`.
`launchd` restarts the app about 10 seconds after a crash, but not after Quit from the menu, because Quit exits with status 0.

### Code signing

macOS files the calendar permission under the app's code signature.
An ad-hoc signature (`codesign --sign -`) changes on every build, so macOS would ask for calendar access again after each rebuild.
`build.sh` signs with the self-signed certificate `You Have a Call Local Signing` from `setup-signing.sh` instead.
The permission then belongs to "this bundle ID, signed by this certificate", which stays the same across builds.

### Speech quirks

`say` reads `<...>` as markup and drops the rest of the sentence, and it runs `[[...]]` as commands.
`spoken()` in `app/Speech.swift` strips both before speaking. The window still shows the original title.

### Known gaps

- Two meetings that start together open two windows, and both voices talk at once.
- The Zoom link pattern has not been tested against a real Zoom invite.
- It is not yet confirmed that macOS keeps syncing Google events while Calendar.app is quit.

`docs/design-options.md` covers the approaches considered and why this one won.
