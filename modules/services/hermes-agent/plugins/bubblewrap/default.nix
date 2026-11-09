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
in
{
  home.activation.hermesSandboxWorkspace = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg "${config.home.homeDirectory}/hermes-workspace"}
  '';
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1200 [ bubblewrapPlugin ];
    extraPackages = with pkgs; [
      bubblewrap
      util-linux
    ];
    settings = {
      terminal = {
        backend = "bubblewrap";
        cwd = "${config.home.homeDirectory}/hermes-workspace";
        degraded_mode = "fail";
        timeout = 600;
      };
      plugins.entries.bubblewrap.settings = {
        profile = "workspace";
        memory_mb = 2048;
        cpu_seconds = 600;
        home_default_deny = "all";
        home_allow = [ "Projects" ];
        binds = [
          {
            src = "/etc/nixos";
            readonly = false;
          }
          {
            src = "${config.home.homeDirectory}/Projects";
            readonly = false;
          }
        ];
      };
    };
  };
}
