{
  virtualisation.oci-containers.containers."actualBudget" = {
    autoStart = true;
    image = "ghcr.io/actualbudget/actual-server:latest";
    ports = [ "5006:5006" ];
    volumes = [ "/var/lib/actual-server:/data" ];
    extraOptions = [ "--pull=always" ];
  };

  services.nginx.virtualHosts."budget.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:5006";
      proxyWebsockets = true;
    };
    kTLS = true;
  };

  systemd.services.restartActualBudget = {
    description = "Restart ActualBudget service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "systemctl restart docker-actualBudget.service";
    };
  };

  systemd.timers.restartActualBudget = {
    wantedBy = [ "timers.target" ];
    partOf = [ "restartActualBudget.service" ];
    timerConfig = {
      OnCalendar = "Wed *-*-* 02:00:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };


  # TODO: Once actual is added to nixos-stable we can implement this.
  # services.actual = {
  #   enable = true;
  #   port = 5007;
  #   settings.hostname = "budget.homehub.tv";
  #   openFirewall = true;
  # };

}
# docker run --pull=always --restart=unless-stopped -d -p 5006:5006 -v /var/lib/actual-budget:/data --name actualBudget ghcr.io/actualbudget/actual-server:latest
