{ den, ... }:
{
  # Desktop profile (hyprland, audio, fonts, printing, ...).
  den.aspects.desktop = {
    includes = [ den.aspects.syncthing ];
    nixos.imports = [ ../desktop/_profile.nix ];
  };
}
