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
  sops.secrets.cloudflare-global-api-key = { };

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
      credentialFiles = {
        "CF_API_EMAIL_FILE" = config.sops.secrets.cloudflare-api-email.path;
        "CF_API_KEY_FILE" = config.sops.secrets.cloudflare-global-api-key.path;
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
