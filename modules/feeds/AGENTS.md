# Feeds and automations

`miniflux.nix` is the reader and the curator's NAS settings; `miniflux-curator.nix` is the curator module and its options; `karakeep-triage.nix` classifies Karakeep bookmarks. Reusable scheduled jobs live here too.

- Make each reusable automation one `den.aspects.<name>` in its own file, with its `den.aspects.<host>.includes` entry in the same file. Put long scripts in a nearby `_` path.
- A one-host job goes in its owning aspect, not a new reusable module.
- Use `systemd.services` with `systemd.timers` or `startAt`, and `Persistent = true` where missed runs must catch up. Put every command the script calls in its `runtimeInputs` or the unit's `path`.
