{ config, ... }:

{
  virtualisation.oci-containers.containers."actualBudget" = {
    autoStart = true;
    image = "ghcr.io/actualbudget/actual-server:latest";
    ports = [ "5006:5006" ];
    volumes = [ "/var/lib/actual-server:/data" ];
    extraOptions = [ "--pull=always" ];
  };

  # Syncthing backup
  services.syncthing.settings.folders."actualBudget" = {
    path = "/var/lib/actual-server";
    devices = [ "server" "workstation" ];
    ignorePerms = true;
  };

  services.nginx.virtualHosts."budget.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:5006";
      proxyWebsockets = true;
    };
  };

}
# docker run --pull=always --restart=unless-stopped -d -p 5006:5006 -v /var/lib/actual-budget:/data --name actualBudget ghcr.io/actualbudget/actual-server:latest
