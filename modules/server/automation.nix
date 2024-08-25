{
  # n8n is a workflow automation tool that allows you to automate tasks.
  services.n8n = {
    enable = true;
    openFirewall = true;
    webhookUrl = "https://command.homehub.tv";
    settings = {
      # The top level domain to serve from
      DOMAIN_NAME = "homehub.tv";

      # The subdomain to serve from
      SUBDOMAIN = "command";

      # Optional timezone to set which gets used by Cron-Node by default
      # If not set New York time will be used
      GENERIC_TIMEZONE = "America/Chicago";
    };
  };

  # Nginx reverse proxy for command
  services.nginx.virtualHosts."command.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:5678";
      proxyWebsockets = true;
    };
  };
}
