{
  # Wi-Fi tooling for the desktop (rofi-network-manager).
  den.aspects.wifi = {
    nixos =
      { pkgs, ... }:
      {
        # Machine specific packages
        environment.systemPackages = with pkgs; [
          rofi-network-manager
        ];
      };
  };
}
