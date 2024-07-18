{ config, pkgs, ... }:

{
  imports = [
    ./ai.nix
    # ./automation.nix
    # ./dns.nix
    ./media.nix
    ./nextcloud.nix
    ./photos.nix
    ./samba.nix
    ./syncthing.nix
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
      server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      dnsResolver = "192.168.254.25:53";
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

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 8384 ];
  };
}
