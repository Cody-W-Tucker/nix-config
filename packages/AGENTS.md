# Local packages

- Add a lowercase kebab-case directory with a single `package.nix` that is a `callPackage` function. Keep patches and lock files beside it. The shared overlay in `modules/flake/_overlay.nix` discovers it automatically; check for collisions with nixpkgs names.
- Use `pkgs.<name>` in consumers, and name other packages as function arguments. Do not add a consumer-side `callPackage` or reference `self.packages`.
- Build with `nix build .#<name>`. If the NAS consumes it, also build its stable variant: `nix build --impure --expr '(builtins.getFlake "/etc/nixos").nixosConfigurations.nas.pkgs.<name>'`.
- Use the [packaging skill](../.agents/skills/nix-packaging/SKILL.md) for ecosystem-specific recipes.
