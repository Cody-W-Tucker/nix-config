{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.karakeep-triage ];

  den.aspects.karakeep-triage.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      triage = pkgs.writeShellScriptBin "karakeep-triage" ''
        exec ${pkgs.python3}/bin/python3 -I ${./_karakeep-triage/triage.py} "$@"
      '';
    in
    {
      environment.systemPackages = [ triage ];

      users.users.karakeep-triage = {
        isSystemUser = true;
        group = "karakeep-triage";
      };
      users.groups.karakeep-triage = { };

      systemd.services.karakeep-triage = {
        description = "Classify Karakeep bookmarks";
        restartIfChanged = false;
        after = [
          "karakeep-web.service"
          "llama-swap.service"
          "laya.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "karakeep-triage";
          Group = "karakeep-triage";
          StateDirectory = "karakeep-triage";
          StateDirectoryMode = "0700";
          LoadCredential = "karakeep-api-key:${config.sops.secrets."karakeep-api-key".path}";
          ExecStart = lib.concatStringsSep " " (
            [
              "${triage}/bin/karakeep-triage"
              "--laya-feedback ${config.services.laya.feedbackSocket}"
              "--services"
            ]
            ++ builtins.attrNames (
              removeAttrs config.services.laya.classifiers.bookmark-route.questions.route.criteria [ "none" ]
            )
          );
          SupplementaryGroups = [ "laya-feedback" ];
          TimeoutStartSec = "2h";
          Nice = 10;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
        };
      };
      systemd.timers.karakeep-triage = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* *:30:00";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };

      nas.backups.sqlite = [
        {
          name = "karakeep-triage";
          source = "/var/lib/karakeep-triage/state.sqlite";
          filename = "state.sqlite";
        }
      ];
    };
}
