# Host Configurations

The flake exports exactly two NixOS configurations, defined in [`flake.nix`](../flake.nix):

- `nixosConfigurations.beast` — evaluates [`hosts/beast`](../hosts/beast) against `nixpkgs-unstable`.
- `nixosConfigurations.nas` — evaluates [`hosts/nas`](../hosts/nas) against stable `nixpkgs`, with `home-manager-stable` bound via `specialArgs`.

Both hosts share foundational modules under [`modules/system/`](../modules/system) (e.g. [`modules/system/base.nix`](../modules/system/base.nix)).

## Beast — Desktop Workstation

- **Composition root:** [`hosts/beast/default.nix`](../hosts/beast/default.nix).
- **Channel:** `nixpkgs-unstable` (see [`flake.nix`](../flake.nix)).
- **Role:** Development, gaming, and local AI workloads.

## NAS — Home Lab Server

- **Composition root:** [`hosts/nas/default.nix`](../hosts/nas/default.nix), with host-local [`hosts/nas/models.nix`](../hosts/nas/models.nix).
- **Channel:** stable `nixpkgs` (`nixos-26.05`), paired with `home-manager-stable` (`release-26.05`).
- **Role:** Central services host for the `homehub.tv` infrastructure. NAS service modules live under [`modules/nas/`](../modules/nas).

## Comparison Summary

| Feature             | Beast (Workstation)                              | NAS (Home Lab)                                       |
| ------------------- | ------------------------------------------------ | ---------------------------------------------------- |
| **Nixpkgs channel** | `nixos-unstable`                                 | `nixos-26.05` (stable)                               |
| **Home Manager**    | `home-manager` (unstable)                        | `home-manager-stable` (`release-26.05`)              |
| **Composition root**| [`hosts/beast/default.nix`](../hosts/beast/default.nix) | [`hosts/nas/default.nix`](../hosts/nas/default.nix)  |
| **Module scope**    | Desktop + AI modules under `modules/`            | NAS service modules under [`modules/nas/`](../modules/nas) |
