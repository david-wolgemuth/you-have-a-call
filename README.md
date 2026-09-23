# You Have a Call

A macOS menu bar app that announces video meetings out loud and grabs focus when they start.

<kbd><img width="565" height="278" alt="Screenshot 2026-09-23 at 13 35 35" src="https://github.com/user-attachments/assets/ad0add65-6f74-4ae6-bb9c-b7cef28e025f" /></kbd>

<kbd><img width="228" height="188" alt="Screenshot 2026-09-23 at 13 35 12" src="https://github.com/user-attachments/assets/94744261-4d8d-4d54-a92f-1508e4c06af1" /></kbd>

## What it does

At a meeting's start time, a window takes focus and a random `say` voice repeats "You have a call: <title>" until you click **Dismiss** or **Snooze 1 min**.

The window's color bar shows whether you accepted the invite.

It reads from macOS Calendar - works if adding external calendars (i.e. Google Calendar).

It alerts for events on your watched calendar that have a Meet or Zoom link and that you have not declined.
The menu bar icon shows the next meeting and can pause alerts for an hour or until tomorrow.

## Set it up

1. Add your Google account in System Settings > Internet Accounts, with Calendars on.
2. In Calendar.app > Settings > Accounts, set Refresh Calendars to every 5 minutes.
3. Put your calendar's title from the Calendar.app sidebar in `watchedCalendars` in `app/Settings.swift`.
4. Run:

   ```sh
   xcode-select --install   # if you don't have the Command Line Tools
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

- Run `./setup-signing.sh` once if you rebuild often. It asks for your login password.
  macOS ties calendar permission to the code signature, and without this certificate `build.sh` falls back to an ad-hoc signature, which changes on every build and re-prompts each time.
- `say` treats `<...>` as markup and `[[...]]` as commands, so `spoken()` strips them.
- Not yet tested: a real Zoom link, and whether sync continues while Calendar.app is quit.

`docs/design-options.md` covers the approaches considered.
