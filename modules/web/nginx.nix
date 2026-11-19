{ den, ... }:
{
  den.aspects.nginx.nixos =
    { lib, config, ... }:

    {
      # System-wide nginx vhost builder.
      # Covers the common reverse-proxy pattern used across this flake:
      #   forceSSL + ACME host + kTLS + single-location proxyPass + websocket proxy.
      #
      # Accepts either:
      #   - `service`: a service name (e.g. "sonarr") — derives host as
      #     "${service}.${baseHost}" and port from
      #     config.services.${service}.settings.server.port
      #   - `host` + `port`: explicit values for services without a standard
      #     settings.server.port option or non-standard hostnames
      #   - `host` + `locations`: explicit values for complex vhosts with multiple
      #     locations or custom location blocks (port not required)
      #
      # `port` accepts an int or string; the helper applies `toString` internally.
      # `locations` accepts a full location attrset for complex vhosts; when provided,
      # the helper uses it verbatim instead of generating a default proxy location.
      # `listen` accepts a list of listen specs for non-standard vhost bindings.
      # `locationExtraConfig` applies extra config to the generated location only.
      # Returns a singleton attrset { "<host>" = { ... }; } suitable for merging
      # into services.nginx.virtualHosts via `//`.
      _module.args.mkNginxVhost =
        {
          host ? null,
          port ? null,
          service ? null,
          baseHost ? null,
          useACMEHost ? config.codyos.site.domain,
          forceSSL ? true,
          kTLS ? true,
          proxyHost ? "127.0.0.1",
          proxyWebsockets ? false,
          locationPath ? "/",
          locationExtraConfig ? "",
          locations ? null,
          listen ? null,
        }:
        let
          resolvedBaseHost = if baseHost != null then baseHost else useACMEHost;
          resolvedHost = if service != null then "${service}.${resolvedBaseHost}" else host;
          resolvedPort = if service != null then config.services.${service}.settings.server.port else port;
          hasCustomLocations = locations != null;
          generatedLocations = {
            ${locationPath} = {
              proxyPass = "http://${proxyHost}:${toString resolvedPort}";
              inherit proxyWebsockets;
            }
            // lib.optionalAttrs (locationExtraConfig != "") { extraConfig = locationExtraConfig; };
          };
          finalLocations = if hasCustomLocations then locations else generatedLocations;
        in
        assert lib.assertMsg (
          resolvedHost != null
        ) "mkNginxVhost: either `host` or `service` must be provided";
        assert lib.assertMsg (
          hasCustomLocations || resolvedPort != null
        ) "mkNginxVhost: either `locations` or `port`/`service` must be provided";
        {
          ${resolvedHost} = lib.filterAttrs (_: v: v != null) (
            {
              locations = finalLocations;
            }
            // lib.optionalAttrs forceSSL { inherit forceSSL; }
            // lib.optionalAttrs kTLS { inherit kTLS; }
            // lib.optionalAttrs (useACMEHost != null) { inherit useACMEHost; }
            // lib.optionalAttrs (listen != null) { inherit listen; }
          );
        };
    };

  # nginx provides the mkNginxVhost module argument to every module on every host.
  den.default.includes = [ den.aspects.nginx ];

  # nginx.server: the NAS ingress. Wildcard ACME certificate for the site domain (DNS-01
  # through Cloudflare), the nginx service with shared proxy settings, a localhost-only
  # stub_status endpoint for the metrics exporter, and the HTTP/HTTPS firewall openings.
  # Service aspects add their own virtual hosts through mkNginxVhost. Included by nas.
  den.aspects.nginx.server.nixos =
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
    };
}
