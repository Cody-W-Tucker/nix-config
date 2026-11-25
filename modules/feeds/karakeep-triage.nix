{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.karakeep-triage ];

  # Files Karakeep bookmarks by topic (local embeddings) and by Laya's bookmark-route
  # classifier. Writes to Karakeep only add tags and list entries.
  den.aspects.karakeep-triage.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      python = pkgs.python3.withPackages (ps: [
        ps.numpy
        ps.scikit-learn
      ]);
      triage = pkgs.writeShellScriptBin "karakeep-triage" ''
        exec ${python}/bin/python3 -I ${./_karakeep-triage/triage.py} "$@"
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
        description = "Group and classify Karakeep bookmarks";
        # A run can take a while; switching must not restart it and wait for it to finish.
        # The next timer run picks up the new version.
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
              removeAttrs config.services.laya.classifiers.bookmark-route.questions.route.criteria [
                "codyos"
                "none"
              ]
            )
          );
          # List contents reach Laya as labels.
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
          OnCalendar = "hourly";
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
