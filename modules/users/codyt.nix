{ inputs, ... }:
{
  # Cody's account. The Home Manager profile that applies on every host; the role
  # (desktop/server), editor and per-host extras are delivered by the host aspects
  # (provides.to-users in modules/hosts/<host>.nix). The users.users.codyt account
  # itself is still defined in modules/_legacy/system/users.nix.
  den.aspects.codyt.homeManager.imports = [
    inputs.nixos-secrets.homeModules.default
  ];
}
