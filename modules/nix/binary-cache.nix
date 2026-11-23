{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.binary-cache.server ];
  den.aspects.beast.includes = [ den.aspects.binary-cache.client ];

  # Binary cache for the other hosts: the NAS serves its store over Tailscale
  # and pre-builds every host from `main` each night (nightly-build.nix), so
  # `update` on beast is a LAN download instead of an internet download or a
  # local compile. One feature, two sides: nas includes `.server`, beast `.client`.

  # Harmonia serves the NAS's /nix/store as a signed binary cache.
  den.aspects.binary-cache.server = {
    includes = [ den.aspects.nightly-build ];

    nixos =
      { config, ... }:

      let
        port = 5000;
      in
      {
        # Generated with `nix key generate-secret --key-name nas-cache-1`.
        # Public half: nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg=
        sops.secrets."nas-cache-signing-key" = { };

        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.sops.secrets."nas-cache-signing-key".path ];
          settings = {
            bind = "[::]:${toString port}";
            # Lower than cache.nixos.org (40), so clients try the LAN copy first.
            priority = 30;
          };
        };

        # Tailscale only; the LAN and the internet never see the cache.
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
      };
  };

  # The NAS pre-builds this host nightly and serves it over Tailscale.
  # mkOrder 400 keeps it ahead of the public caches (the shared nix feature uses mkBefore = 500).
  den.aspects.binary-cache.client.nixos =
    { config, lib, ... }:
    {
      nix.settings = {
        extra-substituters = lib.mkOrder 400 [ "http://${config.codyos.site.hosts.nas.tailscale}:5000" ];
        extra-trusted-public-keys = lib.mkOrder 400 [
          "nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg="
        ];
        # Give up on an unreachable NAS quickly and use the next cache.
        connect-timeout = 5;
      };
    };
}
