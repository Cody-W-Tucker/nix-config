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
    # ./samba.nix
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
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = false; # Disable recommended settings to use custom ones
    recommendedProxySettings = true;

    commonHttpConfig = ''
      gzip on;
      gzip_static on;
      gzip_vary on;
      gzip_comp_level 5;
      gzip_min_length 256;
      gzip_proxied expired no-cache no-store private auth;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
      gzip_buffers 32 8k;
    '';
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 ];
  };
}
