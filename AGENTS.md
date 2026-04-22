# CodyOS

You are assisting a user working on a NixOS system config using flakes.

Here's a overview on common patterns and practices you'll help with.

## Build Testing

Only test builds when making risky changes: new services, complex module refactors, or unfamiliar Nix patterns. Simple edits like updating package lists, changing existing values, or minor configuration tweaks rarely need pre-testing—the user will catch issues during their `update` run.

If the system doesn't build, check the logs and solve the issues.

```bash
# Test build current host
nixos-rebuild dry-run --flake .

# Test build a different host. (Check the hostname of the current session if unsure.)
nixos-rebuild dry-run --flake .#beast

# Checks entire system and all flake outputs.
nix flake check
```

Once the changes have settled, the user will run the `update` script to build and activate the system.

## High-value repo rules

### Naming & Files

- Use lowercase kebab-case for all file names
- Match upstream package names when practical; use CLI-safe kebab-case for internal scripts
- Use quoted attribute names for secret keys with dashes: `sops.secrets."paperless-password"`

### Module Structure

- Naming: `modules/{location}/{item}/default.nix` and file.
- Keep `default.nix` short.
  - Use supporting files with self-explaining names if needed.
  - Examples: `module.nix`, `package.nix` and `service.nix`.
- Keep secrets declarations close to their consuming service

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- Never commit raw secrets (use SOPS-NIX.)
- The user will need to add secrets via the sops edit command.
- You don't have access to the `sudo` command. `sudo` is required to effect a system rebuild.
