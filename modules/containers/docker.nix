{ den, ... }:
{
  den.aspects = {
    beast.includes = [ den.aspects.docker ];
    nas.includes = [
      den.aspects.docker
      den.aspects.docker.oci-backend
    ];

    docker = {
      nixos.virtualisation.docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-backend.nixos.virtualisation.oci-containers.backend = "docker";
    };
  };
}
