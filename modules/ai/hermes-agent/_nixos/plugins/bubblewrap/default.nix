{
  config,
  lib,
  pkgs,
  ...
}:
let
  bubblewrapPlugin = import ../lib/build-plugin.nix pkgs {
    name = "bubblewrap";
    rev = "e7a218f26db88426ab3e7376f0e000b6e356f5e7";
    hash = "sha256-zDjiWUVmWUPAyasy74mUuh+d/dpBi1SBh7GZvuTjxcI=";
    requiresHermes = "0.22.6";
  };
  cfg = config.codyos.hermes-agent.sandbox;
in
{
  options.codyos.hermes-agent.sandbox = {
    binds = lib.mkOption {
      type = with lib.types; listOf (attrsOf (either str bool));
      default = [ ];
      description = "Entries for plugins.entries.bubblewrap.settings.binds.";
    };
    homeAllow = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Entries for plugins.entries.bubblewrap.settings.home_allow.";
    };
  };

  config.codyos.hermes-agent.sandbox.binds = [
    {
      src = "/etc/nixos";
      readonly = true;
    }
  ];

  config.services.hermes-agent = {
    extraPlugins = lib.mkOrder 1200 [ bubblewrapPlugin ];
    extraPackages = with pkgs; [
      bubblewrap
      util-linux
    ];
    settings = {
      terminal = {
        backend = "bubblewrap";
        cwd = config.services.hermes-agent.workingDirectory;
        degraded_mode = "fail";
        timeout = 600;
      };
      plugins.entries.bubblewrap.settings = {
        profile = "network";
        memory_mb = 2048;
        cpu_seconds = 600;
        home_default_deny = "all";
        home_allow = cfg.homeAllow;
        hide = [
          "/run/tailscale"
          "/run/nscd"
          "/run/ssh-unix-local"
          "/run/postgresql"
          "/run/docker.sock"
        ];
        inherit (cfg) binds;
      };
    };
  };
}
