# Apps Aspect

`den.aspects.apps` is the user's desktop applications as one aspect spread over this directory:
`apps.nix` (everyday applications, Zen and Chromium, OBS, Obsidian), `terminal.nix` (Kitty and the
launcher scripts) and `kdeconnect.nix` (phone integration plus its firewall ports).

- `_obsidian/` (vault config, see its README) and `_scripts/` (script builders) are plain modules
  imported by the aspect.
