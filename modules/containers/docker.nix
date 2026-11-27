{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.docker ];
  den.aspects.nas.includes = [
    den.aspects.docker
    den.aspects.docker.oci-backend
  ];

  den.aspects.docker.nixos.virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  den.aspects.docker.oci-backend.nixos.virtualisation.oci-containers.backend = "docker";
}
