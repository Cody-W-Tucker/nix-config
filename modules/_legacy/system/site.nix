# Site-wide facts shared by every host: the primary user, the public domain,
# and LAN/Tailscale addresses. Read them as `config.codyos.site` in NixOS
# modules and `osConfig.codyos.site` in Home Manager modules.
{ config, lib, ... }:

let
  inherit (lib) mkOption types;
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
        default = "codyt";
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
      default = {
        nas = {
          lan = "192.168.1.2";
          tailscale = "100.81.249.65";
        };
        beast = {
          lan = "192.168.1.3";
          tailscale = "100.108.143.19";
          mac = "60:cf:84:7a:a3:4a";
        };
      };
      description = "Addresses of the machines in this flake, keyed by hostname.";
    };
  };
}
