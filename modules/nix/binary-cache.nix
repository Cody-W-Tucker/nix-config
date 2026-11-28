{ den, ... }:
{
  den.aspects = {
    nas.includes = [ den.aspects.binary-cache.server ];
    beast.includes = [ den.aspects.binary-cache.client ];

    binary-cache.server = {
      includes = [ den.aspects.nightly-build ];

      nixos =
        { config, ... }:
        let
          port = 5000;
        in
        {
          sops.secrets."nas-cache-signing-key" = { };

          services.harmonia.cache = {
            enable = true;
            signKeyPaths = [ config.sops.secrets."nas-cache-signing-key".path ];
            settings = {
              bind = "[::]:${toString port}";
              priority = 30;
            };
          };

          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
        };
    };

    binary-cache.client.nixos =
      { config, lib, ... }:
      {
        nix.settings = {
          extra-substituters = lib.mkOrder 400 [ "http://${config.codyos.site.hosts.nas.tailscale}:5000" ];
          extra-trusted-public-keys = lib.mkOrder 400 [
            "nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg="
          ];
          connect-timeout = 5;
        };
      };
  };
}
