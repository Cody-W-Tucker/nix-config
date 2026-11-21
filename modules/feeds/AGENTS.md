# Feeds and automations

Owns Miniflux and the miniflux-curator under `modules/feeds` (`miniflux.nix`: the reader plus the curator's values on nas; `miniflux-curator.nix`: the reusable curator module and its options), and the placement rules for reusable system-level scheduled jobs.

Does not own one-host cron-like tasks unless they are reusable enough to become a module, and does not own user-session launchers or Home Manager tools.

## Placement Rules

- Put each reusable automation in its own kebab-case file (or directory with a `_` supporting tree) as one `den.aspects.<name>`, included by the host that runs it.
- Split longer scripts into nearby `_` files such as `_script.nix`; there is no `default.nix` outside `_` paths.
- Define simple one-host automations in the host module instead of adding a new reusable module.
- Keep secrets close to the consuming automation and use SOPS wiring rather than plaintext values.
- Prefer native `systemd.services` and `systemd.timers` options over ad hoc cron-style glue.

## Failure Modes

- Timer exists but service is not wired to `timers.target` or `startAt`.
- Script depends on commands not present in `runtimeInputs` or the service `path`.
- Service runs as the wrong user and cannot access expected files.
- Long-running or stateful work is modeled as a fragile oneshot without clear working directory, state path, or persistence behavior.
- Data-integrity jobs miss runs because the timer does not use `Persistent = true` where catch-up matters.

See [Feeds and bookmarks](../../docs/src/feeds-and-bookmarks.md) for operating commands.
