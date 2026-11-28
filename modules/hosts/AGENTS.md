# Hosts

A host file holds machine facts only: hostname, disks, network identity, hardware imports, state versions, and `codyos.*` settings for that machine. Features include themselves from their own files; a host file never lists them.

- Do not implement a service inline. When a second host needs host logic, move it into an aspect.
- Use `provides.to-users` here only for machine-local user settings such as `home.stateVersion`.
