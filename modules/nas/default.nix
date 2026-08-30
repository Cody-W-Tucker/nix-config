{
  config,
  mkNginxVhost,
  pkgs,
  ...
}:

{
  imports = [
    ../services/nginx
    ./actual-budget.nix
    ./dawarich.nix
    ./home-assistant.nix
    ./open-webui.nix
    ./adguard.nix
    ./content.nix
    ./excalidraw.nix
    ./gods-eye-view.nix
    ./homepage-dashboard.nix
    ./karakeep.nix
    ./langfuse
    ./litellm
    ./mealie.nix
    ./media
    ./monitoring.nix
    ./nfs.nix
    ./paperless.nix
    ./paperless-gpt.nix
    ./photos.nix
    ./samba.nix
    ./security.nix
    ../services/syncthing.nix
    ./nginx-syncthing.nix
    ./qdrant.nix
    ./tika.nix
    ./uptime-kuma.nix
    ./wake-beast.nix
    ../services/docker.nix
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
        "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-api-key.path;
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
    # Enable access logging for Loki
    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;

      # Access log for Loki ingestion
      access_log /var/log/nginx/access.log;
    '';
    # These services run on the NAS
    virtualHosts =
      # Internal status endpoint for metrics
      mkNginxVhost {
        host = "localhost";
        forceSSL = false;
        kTLS = false;
        useACMEHost = null;
        listen = [
          {
            addr = "127.0.0.1";
            port = 9114;
          }
        ];
        locations = {
          "/nginx_status" = {
            extraConfig = ''
              stub_status on;
              allow 127.0.0.1;
              deny all;
            '';
          };
        };
      };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [
      80
      443
    ];
  };

  # Using Docker as the oci-containers backend
  virtualisation.oci-containers.backend = "docker";
}
