{
  config,
  den,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  hostFacts = lib.mapAttrs (
    _: host:
    {
      inherit (host) lan tailscale;
    }
    // lib.optionalAttrs (host ? mac) { inherit (host) mac; }
  ) config.den.hosts.x86_64-linux;

  userNames = lib.unique (
    lib.concatMap (host: map (user: user.userName) (lib.attrValues host.users)) (
      lib.attrValues config.den.hosts.x86_64-linux
    )
  );
  primaryUserName =
    if lib.length userNames == 1 then
      lib.head userNames
    else
      throw "codyos.site.user.name: den hosts declare users ${toString userNames}; set it explicitly.";
in
{
  den.aspects.site.nixos =
    { config, ... }:
    let
      cfg = config.codyos.site;

      hostType = types.submodule {
        options = {
          lan = mkOption {
            type = types.str;
            description = "Static LAN IPv4 address.";
          };
          tailscale = mkOption {
            type = types.str;
            description = "Tailscale IPv4 address.";
          };
          mac = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Wired MAC address (Wake-on-LAN).";
          };
        };
      };
    in
    {
      options.codyos.site = {
        domain = mkOption {
          type = types.str;
          default = "homehub.tv";
          description = "Public domain. Services are served as <name>.<domain> under one wildcard ACME certificate.";
        };

        user = {
          name = mkOption {
            type = types.str;
            default = primaryUserName;
            defaultText = lib.literalMD "the single Den user entity across `den.hosts` (`codyt`)";
            description = "Primary user account name.";
          };
          email = mkOption {
            type = types.str;
            default = "cody@tmvsocial.com";
            description = "Primary user's email address (git identity, ACME registration).";
          };
          home = mkOption {
            type = types.str;
            default = "/home/${cfg.user.name}";
            defaultText = lib.literalExpression ''"/home/''${config.codyos.site.user.name}"'';
            readOnly = true;
            description = "Primary user's home directory.";
          };
        };

        lan = {
          subnet = mkOption {
            type = types.str;
            default = "192.168.1.0/24";
            description = "LAN subnet in CIDR notation.";
          };
          prefixLength = mkOption {
            type = types.int;
            default = 24;
            description = "LAN prefix length.";
          };
          gateway = mkOption {
            type = types.str;
            default = "192.168.1.1";
            description = "LAN default gateway (Starlink router).";
          };
          broadcast = mkOption {
            type = types.str;
            default = "192.168.1.255";
            description = "LAN broadcast address (Wake-on-LAN).";
          };
        };

        hosts = mkOption {
          type = types.attrsOf hostType;
          description = "Addresses of the machines in this flake, keyed by hostname (populated from the den host attributes in modules/site.nix).";
        };
      };

      config.codyos.site.hosts = lib.mkOptionDefault hostFacts;
    };

  den.default.includes = [ den.aspects.site ];
}
