# Cody Desktop Profile

Owns Cody's user-level desktop environment.

Does not own system desktop plumbing, hardware, audio, groups, udev, or NixOS services. Put those in `modules/desktop` or `modules/services`.

## Placement Rules

- Put app-specific config beside the app, not in broad catch-all files.
- Put small user scripts in `packages/scripts/` unless they belong to a named tool under `harness/`.
- Keep NixVim plugin config under `editor/nixvim/plugins/`.
- Keep Hyprland session behavior in the existing `hyprland/` files.
- Promote shared account behavior up to `../core.nix` only when it also belongs on servers.
