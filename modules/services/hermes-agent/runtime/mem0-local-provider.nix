{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) group stateDir user;

  mem0LocalPlugin = builtins.path {
    path = ./mem0-local-plugin;
    name = "hermes-mem0-local-plugin";
  };
in
{
  config = {
    system.activationScripts.hermes-agent-mem0-local-provider =
      lib.stringAfter [ "hermes-agent-state-access" ]
        ''
          hermes_home="${stateDir}/.hermes"
          plugins_root="$hermes_home/plugins"
          dest_dir="$plugins_root/mem0-local"

          mkdir -p "$plugins_root"
          rm -rf "$dest_dir"
          cp -rL ${mem0LocalPlugin} "$dest_dir"
          chown -R ${user}:${group} "$dest_dir"
          chmod -R u+rwX,g+rwX "$dest_dir"
        '';

    systemd.services.hermes-agent = {
      wants = [ "mem0-http.service" ];
      after = [ "mem0-http.service" ];
    };
  };
}
