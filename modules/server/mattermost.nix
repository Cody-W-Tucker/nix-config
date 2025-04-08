{

  services.mattermost = {
    enable = true;
    siteUrl = "https://chat.homehub.tv";
  };

  services.nginx.virtualHosts."chat.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8065";
        proxyWebsockets = true;
      };
    };
}