# Hosts

Owns machine entry points and host-local facts.

Does not own reusable services, shared desktop behavior, or user preferences. Put those in `modules/` or `users/` and import them here.

## Placement Rules

- Keep one-host choices here: hostname, disks, networking identity, hardware imports, role selection.
- Compose modules; do not implement large services inline in a host file.
- Keep user account behavior in `users/` unless the host is only selecting a profile.
- Move duplicated host logic into `modules/` once a second host wants it.
- New host directories should read as facts plus imports, not a private module tree.
