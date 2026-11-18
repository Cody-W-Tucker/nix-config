{ inputs, ... }:
{
  # NAS server profile: self-hosted services, workflow runtime, VPN confinement.
  den.aspects.nas-role.nixos.imports = [
    ../../modules/nas
    inputs.workflow.nixosModules.default
    inputs.vpn-confinement.nixosModules.default
  ];
}
