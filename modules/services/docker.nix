# Shared Docker policy: enable Docker and prune unused images/containers weekly.
# Hosts that import this module get a consistent baseline; host-specific tweaks
# (package overrides, oci-containers.backend) stay local to the host.
{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
