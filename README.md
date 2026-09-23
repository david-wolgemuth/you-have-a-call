# You Have a Call

A macOS menu bar app that announces video meetings out loud and grabs focus when they start.
It reads macOS Calendar, so there is no Google sign-in and no LLM.

## What it does

At a meeting's start time, a window takes focus and a random `say` voice repeats "You have a call: <title>" until you click **Dismiss** or **Snooze 1 min**.
The window's color bar shows whether you accepted the invite.

It alerts for events on your watched calendar that have a Meet or Zoom link and that you have not declined.
The menu bar icon shows the next meeting and can pause alerts for an hour or until tomorrow.

## Set it up

1. Add your Google account in System Settings > Internet Accounts, with Calendars on.
2. In Calendar.app > Settings > Accounts, set Refresh Calendars to every 5 minutes.
3. Put your calendar's title from the Calendar.app sidebar in `watchedCalendars` in `app/Settings.swift`.
4. Run:

   ```sh
   xcode-select --install   # if you don't have the Command Line Tools
   ./setup-signing.sh       # once; asks for your login password
   ./build.sh && ./install.sh
   ```

5. Click Allow at the calendar prompt. The app now starts at login.

## Use

| To | Do |
|---|---|
| See why a meeting will or won't alert | `./list.sh` |
| Change settings | Edit `app/Settings.swift`, then `./build.sh && ./install.sh` |
| Start again after Quit | `open ~/Applications/"You Have a Call.app"` |
| Uninstall | `./install.sh --uninstall` |

Logs go to `~/Library/Logs/you-have-a-call.log`.

## Notes for working on it

- `setup-signing.sh` exists because macOS ties calendar permission to the code signature. An ad-hoc signature changes on every build and would re-prompt each time.
- `say` treats `<...>` as markup and `[[...]]` as commands, so `spoken()` strips them.
- Not yet tested: a real Zoom link, and whether sync continues while Calendar.app is quit.

`docs/design-options.md` covers the approaches considered.
