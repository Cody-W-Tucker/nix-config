# The desktop (Hyprland)

Beast boots straight into Hyprland: greetd logs in `codyt` on VT1 with no greeter. The first unlock of hyprlock also unlocks the GNOME keyring (secrets and SSH agent). For colors and fonts. For dictation and the voice button, see [Speech](speech.md).

## Launch

`mainMod` is `SUPER`.

| Keys                  | Action                                                                           |
| --------------------- | -------------------------------------------------------------------------------- |
| `SUPER + Tab`         | rofi app launcher (toggle). An already open app is focused, not started again.   |
| `SUPER + Q`           | kitty                                                                            |
| `SUPER + 0`           | Zen; focuses it if it is already open                                            |
| `SUPER + A`           | Open WebUI ([chat.homehub.tv](https://chat.homehub.tv)) as a Chromium app window |
| `SUPER + V`           | Clipboard history in rofi; the selection goes to the clipboard                   |
| `SUPER + Shift + Tab` | rofi web search (NixOS options, GitHub)                                          |
| `SUPER + Backspace`   | rofi calculator; the result goes to the clipboard                                |

## Windows and workspaces

| Keys                      | Action                           |
| ------------------------- | -------------------------------- |
| `SUPER + W`               | Close the window                 |
| `SUPER + F`               | Toggle fullscreen                |
| `SUPER + H` / `SUPER + L` | Move focus left / right          |
| `SUPER + 1`…`9`           | Go to workspace 1–9              |
| `SUPER + Shift + 1`…`9`   | Move the window to workspace 1–9 |
| `SUPER` + LMB / RMB drag  | Move / resize the window         |

Each of these keys toggles a special workspace over the current one. The first toggle starts its program.

| Keys             | Workspace       | Program                                                 |
| ---------------- | --------------- | ------------------------------------------------------- |
| `SUPER + Return` | `special:ai`    | Perplexity (Chromium app)                               |
| `SUPER + D`      | `special:dev`   | kitty                                                   |
| `SUPER + E`      | `special:think` | Excalidraw ([draw.homehub.tv](https://draw.homehub.tv)) |
| `SUPER + Y`      | `special:media` | YouTube                                                 |

## Capture and utilities

| Keys                | Action                                                  |
| ------------------- | ------------------------------------------------------- |
| `SUPER + Shift + S` | Region screenshot to the clipboard (no file is written) |
| `SUPER + S`         | Region OCR; the text goes to the clipboard              |
| `SUPER` + MMB       | Pick a color; it goes to the clipboard                  |
| `SUPER + P`         | Hide or show Waybar                                     |

Media, volume and brightness keys work. The full bind list is in [`_hyprland/settings.nix`](../../modules/graphical/_hyprland/settings.nix).

## Waybar and notifications

- **Left:** workspaces with window icons, the next Google Calendar meeting (click: join link), AI usage.
- **Center:** notification bell, clock, weather. Click the bell for the notification center and Do Not Disturb.
- **Right:** privacy indicators, Hermes voice button, current media, volume, temperature, CPU, memory, disk.

Notifications close after 10 s (low priority: 5 s). Critical ones stay until dismissed. Voice-input notifications stay hidden while you dictate.

## Idle and lock

| Idle time | Result                                                            |
| --------- | ----------------------------------------------------------------- |
| 15 min    | Screen locks (hyprlock)                                           |
| 30 min    | Display turns off                                                 |
| 60 min    | beast suspends. It locks first, so it resumes to the lock screen. |

## Changing it

| To change                                    | Edit                                                                       |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| Binds, special-workspace programs            | [`_hyprland/settings.nix`](../../modules/graphical/_hyprland/settings.nix) |
| Monitors, suspend timeout (`hardwareConfig`) | [`modules/hosts/beast.nix`](../../modules/hosts/beast.nix)                 |
| Lock, idle, login                            | [`hyprland.nix`](../../modules/graphical/hyprland.nix)                     |
| Waybar                                       | [`_waybar/waybar.nix`](../../modules/graphical/_waybar/waybar.nix)         |
| rofi launcher and web search                 | [`launcher.nix`](../../modules/graphical/launcher.nix)                     |
| Notifications                                | [`notifications.nix`](../../modules/graphical/notifications.nix)           |
| Default applications                         | [`xdg.nix`](../../modules/graphical/xdg.nix)                               |
