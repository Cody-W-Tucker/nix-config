# Reusable NixOS Modules

Owns system-level NixOS behavior that hosts compose.

Does not own one-host facts or Home Manager/user preferences. Put those in `hosts/` or `users/`.

## Placement Rules

- Keep reusable services, system defaults, server stacks, and desktop plumbing here.
- Keep host-specific choices in `hosts/`.
- Keep user app configuration in `users/`, even when it supports a system service.
- Put custom service integrations under `services/<name>/default.nix` once they grow past one file.
- Keep `default.nix` files as assembly spines. Small declarations may stay; multi-step processing, scripts, packages, patches, and runtime workflows belong in named supporting files, not `default.nix`.
- Declare secrets close to the consuming service, with quoted names for dashed keys.

## Profiles and Features

- Profiles (`desktop/`, `nas/`) describe a machine role; hosts select them through Den aspects (`den/aspects/desktop.nix`, `den/aspects/nas-role.nix`), which import them.
- Optional features declare `options.codyos.<name>.enable` and wrap their config in `lib.mkIf`. Import them from `modules/base/base.nix` so every host can switch them on. Pure enable gates are set by an aspect in `modules/roles/features.nix`; per-host values (e.g. `nvidiaPowerLimit`) are host attributes in `modules/hosts/<host>.nix`.
- Keep custom options under `codyos.*`, not upstream namespaces like `services.*`, unless deliberately extending an upstream module (e.g. `services.llama-swap`).

## Site Facts

- Never hardcode the domain, username, home path, email, LAN subnet, or host addresses. Read them from `config.codyos.site` (NixOS) or `osConfig.codyos.site` (Home Manager); values live in `modules/base/site.nix`.
- Name service hosts as `"<name>.${domain}"` with `inherit (config.codyos.site) domain;`.
