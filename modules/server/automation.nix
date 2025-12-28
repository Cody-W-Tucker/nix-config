{ config, ... }:

{
  # n8n is a workflow automation tool that allows you to automate tasks.
  services.n8n = {
    enable = true;
    openFirewall = false;
    environment = {
      generic = {
        timezone = config.time.timeZone;
      };
      WEBHOOK_URL = "https://automation.homehub.tv";
      endpoints = {
        metrics = {
          enable = true;
        };
      };
    };
  };

  services.nginx.virtualHosts."automation.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    kTLS = true;
    locations."~ ^/(webhook|webhook-test)" = {
      proxyPass = "http://localhost:${toString config.services.n8n.environment.N8N_PORT}";

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };

    locations."~ ^/rest/oauth2-credential/callback" = {
      proxyPass = "http://localhost:${toString config.services.n8n.environment.N8N_PORT}";

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };

    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.n8n.environment.N8N_PORT}";
      proxyWebsockets = true;

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;

        allow 192.168.1.0/24;
        deny all;
      '';
    };
  };
}
