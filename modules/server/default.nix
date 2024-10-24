{ config, pkgs, ... }:

{
  imports = [
    ./ai.nix
    ./automation.nix
    ./homepage-dashboard.nix
    ./media.nix
    ./monitoring.nix
    ./nextcloud.nix
    ./photos.nix
    ./samba.nix
    ./syncthing.nix
    ./security.nix
  ];

  # Create the acme secret in sops
  sops.secrets.cloudflare-api-email = { };
  sops.secrets.cloudflare-zone-edit-api-key = { };
  sops.secrets.cloudflare-zone-read-api-key = { };

  # Acme for SSL
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "cody@tmvsocial.com";
    };
    certs."homehub.tv" = {
      domain = "homehub.tv";
      extraDomainNames = [ "*.homehub.tv" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      credentialFiles = {
        "CF_API_EMAIL_FILE" = config.sops.secrets.cloudflare-api-email.path;
        "CF_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-zone-edit-api-key.path;
        "CF_ZONE_API_TOKEN_FILE" = config.sops.secrets.cloudflare-zone-read-api-key.path;
      };
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 ];
  };
}
