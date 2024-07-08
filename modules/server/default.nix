{ config, pkgs, ... }:

{
  imports = [
    ./media.nix
    ./photos.nix
    ./samba.nix
    ./homeAssistant.nix
    ./nextcloud.nix
    ./ai.nix
    # ./automation.nix
  ];

  # Acme for SSL
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "cody@tmvsocial.com";
      server = "https://127.0.0.1";
    };
  };

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 8000 ];
  };
}
