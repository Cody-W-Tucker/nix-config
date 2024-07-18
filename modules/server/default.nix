{ config, pkgs, ... }:

{
  imports = [
    ./media.nix
    ./photos.nix
    ./samba.nix
    ./nextcloud.nix
    ./ai.nix
    ./syncthing.nix
    # ./automation.nix
  ];

  # Create the acme secret in sops
  sops.secrets.cloudflare-api-email = { };
  sops.secrets.cloudflare-api-key = { };

  # Acme for SSL
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "cody@tmvsocial.com";
      server = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
    certs."homehub.tv" = {
      domain = "homehub.tv";
      extraDomainNames = [ "*.homehub.tv" ];
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      # inspo: https://go-acme.github.io/lego/dns/cloudflare/
      credentialFiles = {
        "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-api-key.path;
      };
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 8384 ];
  };
}
