{
  # Docker with weekly auto-prune. Included by every host that runs containers
  # (beast, and nas through its role). Host-specific tweaks (package override,
  # oci-containers backend) stay with the host.
  den.aspects.docker.nixos.virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
