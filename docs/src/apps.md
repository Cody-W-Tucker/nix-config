# Desktop apps

The everyday applications on beast. Open any of them from the launcher (`SUPER + Tab`; see [The desktop](desktop.md)).

| For            | App                                                                               |
| -------------- | --------------------------------------------------------------------------------- |
| Browsing       | **Zen** (the default; links open here), Chromium as a second browser with casting |
| Terminal       | **Kitty**; closes without a prompt, no bell                                       |
| Notes          | **Obsidian**, with the `Personal` and `Base` vaults in `~/Knowledge`              |
| Code           | Cursor and Neovim                                                                 |
| AI             | Hermes Desktop, [Herdr](harness.md#herdr) |
| Phone          | KDE Connect, in the tray                                                          |
| Chat and music | Vesktop (Discord), Feishin (music player)                                         |
| Remote help    | RustDesk                                                                          |
| Files          | Nautilus                                                                          |
| Recording      | OBS Studio                                                                        |

Media keys on Bluetooth headphones control whatever is playing.

## Terminal extras

| Command       | What happens                                                                        |
| ------------- | ----------------------------------------------------------------------------------- |
| `ssh- <host>` | SSH with Kitty's extras, so copying in the remote session reaches beast's clipboard |
| `… \| copy`   | Copies the output to the clipboard                                                  |

## Obsidian

Vim mode is on. Closing the window leaves Obsidian running in the tray.

| Keys                         | What happens                    |
| ---------------------------- | ------------------------------- |
| `Ctrl + Shift + Q`           | New quick note                  |
| `Ctrl + M`                   | Move the current note           |
| `Alt + Tab` / `Alt + Escape` | Toggle the left / right sidebar |

The full list is in [`hotkeys.nix`](../../modules/apps/_obsidian/hotkeys.nix).

- **Saving a note tidies it:** headings in Title Case, `-` bullets, some frontmatter date fields removed. Notes in `Admin/` are left as they are.
- **Daily notes** open in `Journal/<year>/<month>/`. Unfinished tasks under _Outstanding Tasks_ move to the next day's note.
- **Each edit in `Personal`** is committed to its Git repo as `vault backup: <date>`. Nothing is pushed.
- **Deleting a note** removes it at once, with no confirmation and no trash.

## Changing it

All in [`modules/apps/`](../../modules/apps):

| To change                          | Edit                                                                                                                |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Apps                               | [`apps.nix`](../../modules/apps/apps.nix)                                                                           |
| Terminal                           | [`terminal.nix`](../../modules/apps/terminal.nix)                                                                   |
| Obsidian settings, plugins, vaults | [`_obsidian/default.nix`](../../modules/apps/_obsidian/default.nix) |
| Phone integration                  | [`kdeconnect.nix`](../../modules/apps/kdeconnect.nix)                                                               |
