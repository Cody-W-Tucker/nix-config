{
  config,
  inputs,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  cfg = config.services.t3code;
  t3code = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
in
{
  options.services.t3code.enable = lib.mkEnableOption "T3 Code remote environment";

  config = lib.mkIf cfg.enable {
    users.users.codyt.linger = true;

    home-manager.users.codyt = {
      home.packages = [ t3code ];
      systemd.user.services.t3code = {
        Unit = {
          Description = "T3 Code remote environment";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart = "${t3code}/bin/t3 serve --host 127.0.0.1 --port 3773";
          Environment = [ "T3CODE_NO_BROWSER=1" ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };

    services.nginx.virtualHosts = mkNginxVhost {
      host = "t3code.homehub.tv";
      port = 3773;
      proxyWebsockets = true;
      proxyHost = "127.0.0.1";
    };
  };
}
