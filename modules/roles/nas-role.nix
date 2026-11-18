{ den, inputs, ... }:
{
  # NAS server profile: self-hosted services, workflow runtime, VPN confinement.
  den.aspects.nas-role = {
    includes = [
      den.aspects.docker
      den.aspects.syncthing
      den.aspects.miniflux-curator
      den.aspects.backup-health
      den.aspects.backups
      den.aspects.binary-cache
      den.aspects.langfuse
      den.aspects.actual-budget
      den.aspects.dawarich
      den.aspects.home-assistant
      den.aspects.open-webui
      den.aspects.dns
      den.aspects.content
      den.aspects.excalidraw
      den.aspects.homepage-dashboard
      den.aspects.karakeep
      den.aspects.mealie
      den.aspects.monitoring
      den.aspects.nfs
      den.aspects.paperless
      den.aspects.paperless-gpt
      den.aspects.photos
      den.aspects.samba
      den.aspects.security
      den.aspects.nginx-syncthing
      den.aspects.tika
      den.aspects.uptime-kuma
      den.aspects.media
    ];
    nixos.imports = [
      ../server/_nas
      inputs.workflow.nixosModules.default
      inputs.vpn-confinement.nixosModules.default
    ];
  };
}
