# Hosts

Owns machine entry points and host-local facts.

Does not own reusable services, shared desktop behavior, or user preferences. Put those in feature aspects under `modules/` and declare their `den.aspects.<host>.includes` or `den.default.includes` entries in the owning feature file.

## Placement Rules

- Keep machine-local settings here: hostname, disks, networking identity, hardware imports, and state versions.
- Compose modules; do not implement large services inline in a host file.
- Keep user account behavior in `modules/users/`; use `provides.to-users` here only for machine-local settings such as the Home Manager state version.
- Move duplicated host logic into an aspect once a second host wants it.
- Host files should read as machine facts and option-carrying `codyos.*` settings, not a private module tree.
