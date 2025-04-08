{ pkgs, ...}:

{

  services.mattermost = {
    enable = true;
    siteUrl = "https://chat.homehub.tv";
    plugins = [
      (pkgs.fetchurl {
        url = "https://github.com/mattermost/mattermost-plugin-boards/releases/download/v9.1.2/mattermost-plugin-boards-v9.1.2-linux-amd64.tar.gz";
        hash = "sha256-vOCL51VCFkiTIro+LSx0N4f2kuqw1t+o0pSNzArdN9E=";
      })
    ];
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