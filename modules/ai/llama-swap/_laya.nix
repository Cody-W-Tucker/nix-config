{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.laya;
  endpoint = import ./_endpoint.nix;
  llamaSwap = "http://127.0.0.1:${toString endpoint.port}";
  policies = "/var/cache/laya/policies";
  hub = "/var/cache/laya/hub";
  registry = pkgs.writeText "laya-classifiers.json" (builtins.toJSON cfg.classifiers);
  command = "${pkgs.laya-vega}/bin/python3 ${./laya-service.py} --classifiers ${registry}";
  publish = pkgs.writeShellScript "laya-publish" ''
    set -euo pipefail
    shopt -s nullglob
    install -d -m 0755 ${policies}
    for policy in /var/lib/laya/*/policy-[0-9]*; do
      target=${policies}/$(basename "$(dirname "$policy")")/$(basename "$policy")
      [[ -d "$policy" && ! -e "$target" ]] || continue
      install -d -m 0755 "$(dirname "$target")"
      draft=$(mktemp -d "$(dirname "$target")/.publish.XXXXXXXX")
      cp -rP "$policy/." "$draft/"
      chmod -R a+rX "$draft"
      mv -T "$draft" "$target"
    done
    [[ ! -d ${hub} ]] || chmod -R a+rX ${hub}
  '';
  feedback = pkgs.writeShellScriptBin "laya-feedback" ''
    exec ${command} feedback "$@"
  '';
  sandbox = {
    User = "laya";
    Group = "laya";
    StateDirectory = "laya";
    StateDirectoryMode = "0700";
    CacheDirectory = "laya";
    CacheDirectoryMode = "0700";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    NoNewPrivileges = true;
    UMask = "0077";
  };
  env = {
    HF_HOME = "/var/cache/laya";
    HF_HUB_DISABLE_TELEMETRY = "1";
    TOKENIZERS_PARALLELISM = "false";
    OMP_NUM_THREADS = "4";
    MKL_NUM_THREADS = "4";
    OPENBLAS_NUM_THREADS = "4";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
  question = lib.types.attrsOf lib.types.anything;
in
{
  options.services.laya = {
    feedbackSocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/laya/feedback.sock";
      readOnly = true;
      description = "Socket that saves human labels; members of the `laya-feedback` group can write to it.";
    };
    defaultTeacher = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "jev-1.14";
      description = "OpenCode Go decision model for requests that carry their own questions.";
    };
    classifiers = lib.mkOption {
      default = { };
      description = "Named classifiers. Only these store labels and train Vega heads.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            questions = lib.mkOption {
              type = lib.types.attrsOf question;
              description = "SystemOne question definitions. Changing them starts a new dataset.";
            };
            teacher = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "jev-1.14";
              description = "OpenCode Go decision model asked when Vega is unsure; null keeps the state on the NAS.";
            };
            learnFromTeacher = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Store confident fallback answers as training labels.";
            };
            minTeacherConfidence = lib.mkOption {
              type = lib.types.numbers.between 0.5 1;
              default = 0.75;
              description = "Fallback confidence (or yes/no probability) needed to accept its label.";
            };
            calibrateOn = lib.mkOption {
              type = lib.types.nonEmptyListOf (
                lib.types.enum [
                  "human"
                  "imported"
                  "teacher"
                ]
              );
              default = [ "human" ];
              description = "Label sources held out to calibrate Vega; labels from the other sources fit its heads.";
            };
            calibrationShare = lib.mkOption {
              type = lib.types.numbers.between 0.05 1;
              default = 1.0;
              description = "Share of states (fixed by a hash of each state) whose `calibrateOn` labels are held out; in the rest they fit the heads. Below 1 lets one source both fit and calibrate.";
            };
            minConfirmed = lib.mkOption {
              type = lib.types.ints.positive;
              default = 30;
              description = "Calibration labels (from `calibrateOn` sources) needed before a trained version is calibrated and published.";
            };
          };
        }
      );
    };
  };

  config = {
    users = {
      users.laya = {
        isSystemUser = true;
        group = "laya";
        extraGroups = [ "laya-feedback" ];
      };
      groups.laya = { };
      groups.laya-feedback = { };
    };
    environment.systemPackages = [ feedback ];

    sops.secrets."opencode-api-key" = { };
    sops.templates."laya-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
      '';
      restartUnits = [ "laya.service" ];
    };

    services.llama-swap.settings.models.vega = {
      ttl = 600;
      cmd = "${command} worker --device cpu --port \${PORT} --state-dir /run/vega/policies";
      env = lib.mapAttrsToList (key: value: "${key}=${value}") (
        env
        // {
          HF_HOME = "/run/vega/hf";
          HF_HUB_OFFLINE = "1";
        }
      );
      checkEndpoint = "/health";
      name = "Vega (Laya CPU worker)";
    };
    services.llama-swap.settings.peers.laya-gateway = {
      proxy = "http://127.0.0.1:${toString endpoint.layaPort}";
      models = [ "laya" ];
      timeouts.responseHeader = 300;
    };

    systemd = {
      services = {
        llama-swap = {
          wants = [ "laya.service" ];
          after = [ "laya.service" ];
          serviceConfig.BindReadOnlyPaths = [
            "-${policies}:/run/vega/policies"
            "-${hub}:/run/vega/hf/hub"
          ];
        };

        laya = {
          description = "Vega-backed Laya SystemOne decisions";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          environment = env;
          path = [ pkgs.coreutils ];
          serviceConfig = sandbox // {
            EnvironmentFile = config.sops.templates."laya-env".path;
            ExecStartPre = publish;
            ExecStart = lib.concatStringsSep " " (
              [
                "${command} serve --port ${toString endpoint.layaPort}"
                "--worker-url ${llamaSwap}/upstream/vega"
                "--teacher-url https://opencode.ai/inference/go/systemone/v1/systemone"
                "--feedback-socket ${cfg.feedbackSocket} --feedback-group laya-feedback"
              ]
              ++ lib.optional (cfg.defaultTeacher != null) "--default-teacher ${cfg.defaultTeacher}"
            );
            Restart = "on-failure";
            RuntimeDirectory = "laya";
            RuntimeDirectoryMode = "0755";
          };
        };

        laya-train = {
          description = "Refit Laya heads from stored labels";
          after = [
            "laya.service"
            "llama-swap.service"
          ];
          environment = env;
          path = [ pkgs.coreutils ];
          serviceConfig = sandbox // {
            Type = "oneshot";
            ExecStart = "${command} train --device cpu";
            ExecStopPost = "-${publish}";
            Nice = 15;
            CPUQuota = "200%";
            IOWeight = 10;
            TimeoutStartSec = "45min";
          };
        };
      };

      timers.laya-train = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 01:00:00";
          Persistent = false;
        };
      };
    };
  };
}
