# Shared Docker policy: enable Docker and prune unused images/containers weekly.
# Hosts that enable this get a consistent baseline; host-specific tweaks
# (package overrides, oci-containers.backend) stay local to the host.
{ config, lib, ... }:

{
  options.codyos.docker.enable = lib.mkEnableOption "Docker with weekly auto-prune";

  config = lib.mkIf config.codyos.docker.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
