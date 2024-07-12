{ config, ... }:

{
  virtualisation.oci-containers.containers."actualBudget" = {
    autoStart = true;
    image = "ghcr.io/actualbudget/actual-server:latest";
    ports = [ "5006:5006" ];
    volumes = [ "/var/lib/actual-server:/data" ];
    extraOptions = [ "--pull=always" ];
  };


}
# docker run --pull=always --restart=unless-stopped -d -p 5006:5006 -v /var/lib/actual-budget:/data --name actualBudget ghcr.io/actualbudget/actual-server:latest
