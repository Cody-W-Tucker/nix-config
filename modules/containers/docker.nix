{
  # Docker with weekly auto-prune. Included by every host that runs containers
  # (beast, nas). Host-specific tweaks (e.g. nas's package override) stay with the host.
  den.aspects.docker.nixos.virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # oci-containers backend for the NAS services that run as containers (langfuse,
  # paperless-gpt, ...). Included by nas.
  den.aspects.docker.oci-backend.nixos.virtualisation.oci-containers.backend = "docker";
}
