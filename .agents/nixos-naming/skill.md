# NixOS Naming

Use this guide when naming files, folders, modules, custom options, and secrets in a NixOS repository.

## Core convention

Use lowercase kebab-case almost everywhere.

## File naming

### Preferred

- `hardware-configuration.nix`
- `paperless-ngx.nix`
- `homepage-dashboard.nix`
- `home-manager.nix`

### Avoid

- `paperlessNgx.nix`
- `paperless_ngx.nix`
- `Paperless.nix`

## Directory naming

- Use lowercase directory names.
- Use kebab-case when a name contains multiple words.
- Keep category names short and obvious: `hosts/`, `modules/`, `home/`, `users/`, `pkgs/`, `lib/`, `secrets/`.

## Required conventional names

- `flake.nix` at repository root.
- `flake.lock` at repository root.
- `default.nix` for importable directories.
- `hardware-configuration.nix` for generated hardware config.
- `configuration.nix` only when intentionally keeping the classic NixOS entrypoint.

## Host names

- Name host files after the actual hostname when possible.
- Examples: `hosts/beast.nix`, `hosts/server.nix`, `hosts/ai-server.nix`.
- If a host needs multiple files, use `hosts/<hostname>/default.nix`.

## Module names

- Name modules after the feature, service, or responsibility they own.
- Good: `nginx.nix`, `tailscale.nix`, `nvidia.nix`, `printing.nix`.
- Avoid vague names like `stuff.nix`, `extra.nix`, or `misc.nix`.

## Custom option names

- Namespace custom options under your own prefix.
- Example: `my.services.paperless.enable`.
- Keep option paths descriptive and stable.
- Prefer singular feature names over overloaded buckets.

## Secret names

- Use quoted attribute names when the key contains dashes.
- Example: `sops.secrets."paperless-password" = { };`
- Match the consuming service name where possible.
- Avoid generic names like `password1` or `api-key` without context.

## Package names

- Match upstream naming when practical.
- If packaging an internal script, choose a CLI-safe name in kebab-case.
- Keep file name and package name aligned when possible.

## Import aggregators

- Use `default.nix` for directories meant to be imported directly.
- Keep aggregator file names predictable. Do not invent aliases like `all.nix` unless there is a strong reason.

## Naming checklist

- Is the name lowercase?
- Is it kebab-case?
- Does it describe one thing clearly?
- Does it align with the service or feature it configures?
- Would a new contributor guess its contents correctly from the name?

## Rule of thumb

If a name needs explanation every time someone reads it, rename it.
