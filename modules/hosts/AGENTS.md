# Hosts

Owns machine entry points and host-local facts.

Does not own reusable services, shared desktop behavior, or user preferences. Put those in aspects under `modules/` (`nix/`, `shell/`, `desktop/`, `web/`, `feeds/`, `ai/`, `documents/`, `media/`, `users/`) and include them from the host aspect.

## Placement Rules

- Keep one-host choices here: hostname, disks, networking identity, hardware imports, role selection.
- Compose modules; do not implement large services inline in a host file.
- Keep user account behavior in `modules/users/`; a host only selects what to deliver through `provides.to-users`.
- Move duplicated host logic into an aspect once a second host wants it.
- Host files should read as machine facts and option-carrying `codyos.*` settings, not a private module tree.
