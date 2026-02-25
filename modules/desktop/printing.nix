{ pkgs, ... }:
{
  # Avahi configured in casting.nix for Chromecast/printing shared use

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
      canon-cups-ufr2
    ];
  };
}
