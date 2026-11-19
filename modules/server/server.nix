{ den, inputs, ... }:
{
  # Server role (nas): self-hosted services, workflow runtime, VPN confinement.
  # Include order matters for list-valued options (den concatenates included modules
  # in reverse include order), e.g. nas.backups.sqlite keeps its legacy order.
  den.aspects.server = {
    includes = [
      den.aspects.docker
      den.aspects.syncthing
      den.aspects.miniflux-curator
      den.aspects.backup-health
      den.aspects.backups
      den.aspects.binary-cache.server
      den.aspects.langfuse
      den.aspects.actual-budget
      den.aspects.dawarich
      den.aspects.home-assistant
      den.aspects.open-webui
      den.aspects.dns
      den.aspects.content
      den.aspects.excalidraw
      den.aspects.homepage-dashboard
      den.aspects.karakeep
      den.aspects.mealie
      den.aspects.monitoring
      den.aspects.nfs
      den.aspects.paperless
      den.aspects.paperless-gpt
      den.aspects.photos
      den.aspects.samba
      den.aspects.security
      den.aspects.nginx-syncthing
      den.aspects.tika
      den.aspects.uptime-kuma
      den.aspects.media
    ];

    nixos =
      {
        config,
        mkNginxVhost,
        pkgs,
        ...
      }:
      let
        inherit (config.codyos.site) domain;
      in
      {
        imports = [
          inputs.workflow.nixosModules.default
          inputs.vpn-confinement.nixosModules.default
        ];

        # NAS services run in Docker (den.aspects.docker, included by the nas role;
        # oci-containers backend below).
        # Create the acme secret in sops
        sops.secrets.cloudflare-api-email = { };
        sops.secrets.cloudflare-api-key = { };

        # Acme for SSL
        security.acme = {
          acceptTerms = true;
          defaults = {
            inherit (config.codyos.site.user) email;
          };
          certs.${domain} = {
            inherit domain;
            extraDomainNames = [ "*.${domain}" ];
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
      };
  };
}
