{ den, ... }:
{
  den.default.includes = [ den.aspects.nginx ];

  den.aspects = {
    nas.includes = [ den.aspects.nginx.server ];

    nginx = {
      nixos =
        { lib, config, ... }:
        {
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
              finalLocations =
                if hasCustomLocations then
                  locations
                else
                  {
                    ${locationPath} = {
                      proxyPass = "http://${proxyHost}:${toString resolvedPort}";
                      inherit proxyWebsockets;
                    }
                    // lib.optionalAttrs (locationExtraConfig != "") { extraConfig = locationExtraConfig; };
                  };
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

      server.nixos =
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
          sops.secrets = {
            cloudflare-api-email = { };
            cloudflare-api-key = { };
          };
          security.acme = {
            acceptTerms = true;
            defaults = {
              inherit (config.codyos.site.user) email;
            };
            certs.${domain} = {
              extraDomainNames = [ "*.${domain}" ];
              dnsProvider = "cloudflare";
              dnsResolver = "1.1.1.1:53";
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
            appendHttpConfig = ''
              proxy_headers_hash_max_size 1024;
              proxy_headers_hash_bucket_size 128;
              access_log /var/log/nginx/access.log;
            '';
            virtualHosts = mkNginxVhost {
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
              locations."/nginx_status".extraConfig = ''
                stub_status on;
                allow 127.0.0.1;
                deny all;
              '';
            };
          };

          users.users.nginx.extraGroups = [ "acme" ];

          networking.firewall = {
            allowedTCPPorts = [
              80
              443
            ];
          };
        };
    };
  };
}
