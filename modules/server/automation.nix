{ config, ... }:

{
  # n8n is a workflow automation tool that allows you to automate tasks.
  services.n8n = {
    enable = true;
    openFirewall = true;
    webhookUrl = "https://automation.homehub.tv";
    settings = {
      generic = {
        timezone = config.time.timeZone;
      };
      endpoints = {
        metrics = {
          enable = true;
        };
      };
    };
  };

  virtualHosts."automation.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."~ ^/(webhook|webhook-test)" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.settings.port}";

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };

    locations."~ ^/rest/oauth2-credential/callback" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.settings.port}";

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.n8n.settings.port}";
      proxyWebsockets = true;

      extraConfig = ''
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;

        allow 192.168.254.0/24;
        deny all;
      '';
    };
  };
}
