{
  mkNginxVhost,
  ...
}:

{
  services.n8n = {
    enable = true;
    openFirewall = false;
    environment = {
      N8N_HOST = "n8n.homehub.tv";
      N8N_PORT = "5678";
      N8N_PROTOCOL = "https";
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      WEBHOOK_URL = "https://n8n.homehub.tv/";
      GENERIC_TIMEZONE = "America/Chicago";
      TZ = "America/Chicago";
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "n8n.homehub.tv";
    port = 5678;
    proxyWebsockets = true;
  };
}
