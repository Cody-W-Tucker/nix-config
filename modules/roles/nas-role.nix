{ den, inputs, ... }:
{
  # NAS server profile: self-hosted services, workflow runtime, VPN confinement.
  den.aspects.nas-role = {
    includes = [
      den.aspects.docker
      den.aspects.syncthing
      den.aspects.miniflux-curator
    ];
    nixos.imports = [
      ../server/_nas
      inputs.workflow.nixosModules.default
      inputs.vpn-confinement.nixosModules.default
    ];
  };
}
