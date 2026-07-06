# Automations

Owns reusable system-level scheduled jobs and automation services under `modules/services/automations`.

Does not own one-host cron-like tasks unless they are reusable enough to become a module, and does not own user-session launchers or Home Manager tools.

## Placement Rules

- Put each reusable automation in its own kebab-case directory with `default.nix` as the module entry point.
- Split longer scripts into nearby files such as `script.nix`; keep `default.nix` as the service/timer assembly point.
- Define simple one-host automations in the host module instead of adding a new reusable module.
- Keep secrets close to the consuming automation and use SOPS wiring rather than plaintext values.
- Prefer native `systemd.services` and `systemd.timers` options over ad hoc cron-style glue.

## Failure Modes

- Timer exists but service is not wired to `timers.target` or `startAt`.
- Script depends on commands not present in `runtimeInputs` or the service `path`.
- Service runs as the wrong user and cannot access expected files.
- Long-running or stateful work is modeled as a fragile oneshot without clear working directory, state path, or persistence behavior.
- Data-integrity jobs miss runs because the timer does not use `Persistent = true` where catch-up matters.

See `README.md` for examples, common options, and operating commands.
