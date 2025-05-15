{ config, pkgs, ... }:

{
  imports = [
    ./actualBudget.nix
    ./ai.nix
    ./arm.nix
    ./adguard.nix
    ./automation.nix
    # ./collabora.nix
    ./content.nix
    ./data.nix
    ./excalidraw.nix
    ./hoarder.nix
    ./homepage-dashboard.nix
    ./mattermost.nix
    ./media.nix
    ./monitoring.nix
    # ./nextcloud.nix
    ./paperless.nix
    ./paperless-scanning.nix
    ./stirling-pdf.nix
    ./photos.nix
    ./samba.nix
    ./syncthing.nix
    ./security.nix
  ];

  # Create the acme secret in sops
  sops.secrets.cloudflare-api-email = { };
  sops.secrets.cloudflare-api-key = { };

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
        "CF_API_TOKEN_FILE" = config.sops.secrets.cloudflare-api-key.path;
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
    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 ];
  };

  # Using Docker
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    oci-containers.backend = "docker";
  };
}
