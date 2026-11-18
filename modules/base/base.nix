{ den, ... }:
{
  # Shared baseline for every host: one aspect per concern, plus the hardware baseline.
  # Per-host site facts (lan, tailscale, mac) come from the den host attributes in
  # modules/hosts/<host>.nix; modules/base/site.nix turns them into `codyos.site.hosts`.
  den.aspects.base = {
    includes = [
      den.aspects.sops
      den.aspects.scripts
      den.aspects.locale
      den.aspects.nix
      den.aspects.overlays
      den.aspects.accounts
      den.aspects.packages
      den.aspects.shell
      den.aspects.core-services
      den.aspects.networking
      den.aspects.logging
      den.aspects.site
      den.aspects.hardware-baseline
      # nginx provides the mkNginxVhost module argument to every module on every host.
      den.aspects.nginx
    ];

    nixos = {
      # https://emudhra.we-have-a-problem.com/
      security.pki.caCertificateBlacklist = [
        "Comodo AAA Services root"
      ];
    };
  };
}
