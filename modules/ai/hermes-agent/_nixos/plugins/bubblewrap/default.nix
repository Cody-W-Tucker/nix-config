{
  config,
  lib,
  pkgs,
  ...
}:
let
  sandboxPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "e7a218f26db88426ab3e7376f0e000b6e356f5e7";
    hash = "sha256-zDjiWUVmWUPAyasy74mUuh+d/dpBi1SBh7GZvuTjxcI=";
  };
  bubblewrapPlugin = pkgs.runCommand "bubblewrap" { } ''
    cp -R ${sandboxPlugins}/bubblewrap "$out"
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.22.6"' 'requires_hermes: ">=0.0.0"'
  '';
  cfg = config.codyos.hermes-agent.sandbox;
in
{
  # Upstream merges settings with recursiveUpdate, where a later list replaces
  # an earlier one. Features add sandbox entries here instead.
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

  # The live checkout `update` applies. Hermes changes CodyOS in its own
  # clone in the workspace (see documents/default.nix).
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
        # The host network, limited by the hermes user's egress policy
        # (egress/default.nix).
        profile = "network";
        memory_mb = 2048;
        cpu_seconds = 600;
        home_default_deny = "all";
        home_allow = cfg.homeAllow;
        # Sockets that reach past the egress policy: tailscaled (`tailscale nc`
        # to any tailnet host and port), sshd's local socket and PostgreSQL.
        # The units close them too; cron jobs run outside the units.
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
