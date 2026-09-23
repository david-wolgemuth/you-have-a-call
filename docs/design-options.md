# Design options

We chose a single Swift file, compiled with `swiftc` into a hand-built `.app`.
It is the only option that holds its own calendar permission and can take focus from other apps without Xcode.

## The problem is salience, not volume

Chrome and Slack already notify about meetings, but they also carry routine traffic such as GitHub activity, so their alerts no longer register.
The fix is a channel that only meetings use: a spoken alert and a window that takes focus.

## The data source is macOS Calendar through EventKit

The work Google account syncs into macOS Calendar. EventKit (the macOS framework that reads Calendar.app's local event store) can read those events.
That avoids Google OAuth, which the Workspace admin blocks for third-party apps, and it avoids an MCP or LLM in the loop.

## Calendar permission decided the choice

macOS only lets a process read the calendar if it declares a usage description in an `Info.plist`.
A plain script has none, so macOS either borrows the terminal's permission or denies the request. Denial is most likely when `launchd` (the macOS service manager) starts the script at login.
A `.app` bundle carries its own `Info.plist`, so it holds its own permission.

## Options considered

| Option | Why not chosen |
|---|---|
| Python with PyObjC (a Python bridge to macOS frameworks) | The permission belongs to the `python` binary, which has no usage description. The window code is AppKit written in Python syntax, so it is no easier. |
| Hammerspoon (a macOS automation app scripted in Lua) | Good alert primitives, but it cannot read EventKit, so it needs a second program for the calendar. |
| AppleScript or JXA against Calendar.app | Calendar.app scripting takes several seconds per query, and `display dialog` does not reliably take focus. |
| tkinter | The pyenv Python on this Mac lacks `_tkinter`. It still needs a calendar source, and it cannot float above full-screen apps. |
| In Your Face (commercial app) | Its Google sign-in is blocked by the Workspace admin. |

## A Join button was dropped

Chrome can open a URL inside an installed web app from the command line:

```sh
open -na "Google Chrome" --args --profile-directory=Default \
  --app-id=kjgfgldnnfoeklkmfkjfagphfepbbdan \
  --app-launch-url-for-shortcuts-menu-item="https://meet.google.com/abc-defg-hij"
```

This works, but it opens a new Meet app window instead of reusing the one already open.
Chrome's AppleScript dictionary does not list web app windows, so no script can navigate the existing window without Accessibility-based UI scripting.
The Meet app is always open already, so the alert only needs to get attention, and the button was removed.

## Signing uses a local certificate

An ad-hoc signature changes on every build, so macOS treated each rebuild as a new app and asked for calendar access again.
A self-signed certificate gives the app a designated requirement of "identifier plus certificate", which stays the same across builds. See the README for setup.
