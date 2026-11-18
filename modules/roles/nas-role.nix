{ inputs, ... }:
{
  # NAS server profile: self-hosted services, workflow runtime, VPN confinement.
  den.aspects.nas-role.nixos.imports = [
    ../_legacy/nas
    inputs.workflow.nixosModules.default
    inputs.vpn-confinement.nixosModules.default
  ];
}
