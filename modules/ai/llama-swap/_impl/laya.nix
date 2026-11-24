{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.laya;
  endpoint = import ../_endpoint.nix;
  # Serving and training each hold their own lease, so both are counted when both run.
  leases = {
    laya-gpu = 2600;
    laya-train-gpu = 2600;
  };
  lease = model: "--lease-url http://127.0.0.1:${toString endpoint.port} --lease-model ${model}";
  registry = pkgs.writeText "laya-classifiers.json" (builtins.toJSON cfg.classifiers);
  run = python: "${python}/bin/python3 ${./laya-service.py} --classifiers ${registry}";
  command = run pkgs.laya-vega;
  # Serving, training and calibration read on the GPU when it has room, otherwise on the CPU.
  gpu = run (pkgs.laya-vega.override { cudaSupport = true; });
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
                ]
              );
              default = [ "human" ];
              description = "Label sources held out to calibrate Vega; labels from the other sources fit its heads.";
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
    users.users.laya = {
      isSystemUser = true;
      group = "laya";
    };
    users.groups.laya = { };
    environment.systemPackages = [ feedback ];

    # Same opencode-api-key Hermes and Hindsight use, rendered for this unit.
    sops.secrets."opencode-api-key" = { };
    sops.templates."laya-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
      '';
      restartUnits = [ "laya.service" ];
    };

    # Laya's GPU lease: an empty llama-swap model that declares Vega's VRAM, so the
    # capacity router counts it and evicts it like any model. Laya loads it before
    # reading on the GPU and drops to the CPU once it is gone (evicted or idle).
    services.llama-swap.enabledModels = builtins.attrNames leases;
    services.llama-swap.modelOverrides = lib.mapAttrs (_: vram: {
      file = null;
      ttl = 600;
      upstream = {
        cmd = "${pkgs.python3}/bin/python3 -m http.server \${PORT} --bind 127.0.0.1 --directory ${pkgs.emptyDirectory}";
        checkEndpoint = "/";
        unlisted = true;
        capacities.vram = vram;
        evict_cost = 20;
      };
    }) leases;

    # Peer dispatch holds no capacity; the lease above does.
    services.llama-swap.settings.peers.vega = {
      proxy = "http://127.0.0.1:${toString endpoint.layaPort}";
      models = [ "laya" ];
      timeouts.responseHeader = 300;
    };

    systemd.services.laya = {
      description = "Vega-backed Laya SystemOne decisions";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = env;
      serviceConfig = sandbox // {
        EnvironmentFile = config.sops.templates."laya-env".path;
        ExecStart = lib.concatStringsSep " " (
          [
            "${gpu} serve --device cuda ${lease "laya-gpu"} --port ${toString endpoint.layaPort}"
            "--teacher-url https://opencode.ai/inference/go/systemone/v1/systemone"
          ]
          ++ lib.optional (cfg.defaultTeacher != null) "--default-teacher ${cfg.defaultTeacher}"
        );
        Restart = "on-failure";
        PrivateDevices = false;
      };
    };

    systemd.services.laya-train = {
      description = "Refit Laya heads from stored labels";
      after = [ "laya.service" ];
      environment = env;
      serviceConfig = sandbox // {
        Type = "oneshot";
        # Large refits wait for evenings and weekends in the NAS's local time.
        ExecStart = "${gpu} train --device cuda ${lease "laya-train-gpu"}";
        PrivateDevices = false;
        Nice = 15;
        CPUQuota = "200%";
        IOWeight = 10;
        TimeoutStartSec = "2h";
      };
    };
    systemd.timers.laya-train = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
