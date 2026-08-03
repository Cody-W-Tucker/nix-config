{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-swap;

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        file = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GGUF file name inside the llama-swap model directory. Leave null when `upstream.cmd` fully replaces the generated llama-server command.";
        };

        alias = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Alias exposed by llama-server.";
        };

        mmprojFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional multimodal projector GGUF file name passed to llama-server with `--mmproj`. Download it from the same release as the base GGUF and store it under a model-specific name to avoid filename collisions such as `mmproj-F16.gguf`.";
        };

        ttl = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "Seconds to keep the model process alive after it becomes idle.";
        };

        contextSize = lib.mkOption {
          type = lib.types.int;
          default = 65536;
          description = "Context window passed to llama-server with `-c`.";
        };

        batchSize = lib.mkOption {
          type = lib.types.int;
          default = 2048;
          description = "Batch size passed to llama-server with `-b`.";
        };

        ubatchSize = lib.mkOption {
          type = lib.types.int;
          default = 1024;
          description = "Micro-batch size passed to llama-server with `-ub`.";
        };

        threads = lib.mkOption {
          type = lib.types.int;
          default = 16;
          description = "CPU thread count passed to llama-server with `-t`.";
        };

        gpuLayers = lib.mkOption {
          type = lib.types.int;
          default = 999;
          description = "Maximum GPU layers passed to llama-server with `--n-gpu-layers`.";
        };

        flashAttention = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable flash attention.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional llama-server arguments appended to the generated command.";
        };

        upstream = lib.mkOption {
          inherit (settingsFormat) type;
          default = { };
          description = "Raw llama-swap model settings merged over the generated defaults. Use this to override `cmd` or add upstream-only fields such as `proxy`, `aliases`, or `concurrencyLimit`.";
        };
      };
    }
  );

  defaultModelCatalog = import ./models.nix;
  proxy = import ./proxy.nix { inherit pkgs; };
  settingsFormat = pkgs.formats.yaml { };
  llamaCppStrix = pkgs.callPackage ../../../packages/llama-cpp-strix { };

  defaultServerPackage =
    if cfg.acceleration == "rocm" then
      llamaCppStrix
    else if cfg.acceleration == "cuda" then
      pkgs.llama-cpp.override { cudaSupport = true; }
    else
      pkgs.llama-cpp;

  backendEnvironment =
    if cfg.acceleration == "rocm" then
      {
        HSA_OVERRIDE_GFX_VERSION = "11.5.1";
        HIP_PATH = "${pkgs.rocmPackages.rocm-core}";
        ROCM_PATH = "${pkgs.rocmPackages.rocm-core}";
      }
    else
      { };

  # Build Python environments for audio wrapper services
  whisperPython = proxy.mkWhisperPython cfg.ctranslate2Cpp;
  kokoroPython = proxy.mkKokoroPython pkgs;
  whisperDiarizePython = proxy.mkWhisperDiarizePython pkgs;

  # Build wrapper commands for audio models
  wrapperCommands = {
    "whisper-medium" = {
      file = null;
      ttl = 0;
      upstream.cmd = ''
        ${whisperPython}/bin/python3 ${./faster-whisper-openai-server.py} \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model medium.en \
          --model-id whisper-medium \
          --device cuda \
          --compute-type int8 \
          --download-root ${proxy.sharedFasterWhisperCache} \
          --vad-filter \
          --language en
      '';
    };
    "whisper-diarization" = {
      file = null;
      ttl = 0;
      upstream.cmd = ''
        env HOME=${proxy.diarizationCache} \
        PYTHONPATH=${./.} \
        ${whisperDiarizePython}/bin/python3 -m diarization.server \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model-id whisper-diarization \
          --device cuda \
          --compute-type float16 \
          --download-root ${proxy.diarizationCache} \
          --enrollment-dir ${proxy.diarizationEnrollmentDir} \
          --hf-token-path ${cfg.hfTokenPath}
      '';
    };
    "kokoro-82m" = {
      file = null;
      ttl = 0;
      upstream.cmd = ''
        ${kokoroPython}/bin/python3 ${./kokoro-openai-server.py} \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model-id kokoro-82m \
          --lang-code a \
          --default-voice af_heart \
          --voices-dir ${proxy.kokoroAssets} \
          --model-path ${proxy.kokoroAssets}/kokoro-v1_0.pth \
          --config-path ${proxy.kokoroAssets}/config.json
      '';
    };
  };

  resolvedModelCatalog = lib.recursiveUpdate (lib.recursiveUpdate cfg.modelCatalog wrapperCommands) cfg.modelOverrides;

  missingModels = lib.filter (name: !(builtins.hasAttr name resolvedModelCatalog)) cfg.enabledModels;
  unknownPreloads = lib.filter (name: !(builtins.elem name cfg.enabledModels)) cfg.preloadModels;

  selectedModels = lib.filterAttrs (
    name: _: builtins.elem name cfg.enabledModels
  ) resolvedModelCatalog;

  modelsMissingFileAndCmd = lib.mapAttrsToList (
    name: model: lib.optional (model.file == null && !((model.upstream or { }) ? cmd)) name
  ) selectedModels;
  invalidGeneratedModels = lib.flatten modelsMissingFileAndCmd;

  llamaServer = lib.getExe' cfg.serverPackage "llama-server";

  mkModelCommand =
    model:
    lib.concatStringsSep " " (
      [
        llamaServer
        "--port"
        "\${PORT}"
        "-m"
        "${cfg.modelDirectory}/${model.file}"
        "--alias"
        model.alias
        "--no-webui"
      ]
      ++ lib.optionals model.flashAttention [
        "--flash-attn"
        "on"
      ]
      ++ [
        "--n-gpu-layers"
        (toString model.gpuLayers)
        "-c"
        (toString model.contextSize)
        "-b"
        (toString model.batchSize)
        "-ub"
        (toString model.ubatchSize)
        "-t"
        (toString model.threads)
      ]
      ++ lib.optionals (model.mmprojFile != null) [
        "--mmproj"
        (
          if lib.hasPrefix "/" model.mmprojFile then
            model.mmprojFile
          else
            "${cfg.modelDirectory}/${model.mmprojFile}"
        )
      ]
      ++ model.extraArgs
    );

  renderedModels = lib.mapAttrs (
    _: model:
    (lib.optionalAttrs (!(model.upstream or { } ? cmd)) {
      cmd = mkModelCommand model;
    })
    // {
      inherit (model) ttl;
    }
    // (model.upstream or { })
  ) selectedModels;
in
{
  options.services.llama-swap = {
    acceleration = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "cuda"
        "rocm"
      ];
      default = "cpu";
      description = "Backend used to build the llama-server package and service environment.";
    };

    serverPackage = lib.mkOption {
      type = lib.types.package;
      default = defaultServerPackage;
      defaultText = lib.literalExpression "pkgs.llama-cpp";
      description = "llama.cpp package that provides the llama-server binary used by llama-swap.";
    };

    ctranslate2Cpp = lib.mkOption {
      type = lib.types.package;
      default = proxy.defaultCTranslate2Cpp;
      defaultText = lib.literalExpression "pkgs.ctranslate2";
      description = "ctranslate2 package used by the faster-whisper Python environment. Override for architecture-specific CUDA builds.";
    };

    hfTokenPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to Hugging Face token file for authenticated model downloads.";
    };

    modelDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/srv/llama-swap/models";
      description = "Directory that stores GGUF files served by llama-swap.";
    };

    modelOwner = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Owner for the managed model directory.";
    };

    modelGroup = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group for the managed model directory.";
    };

    modelCatalog = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = defaultModelCatalog;
      description = "Catalog of named llama-swap model definitions.";
    };

    modelOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Host-specific overrides merged onto `services.llama-swap.modelCatalog`.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      readOnly = true;
      description = "Resolved model definitions after merging catalog, wrapper commands, and overrides. Read-only; populated by the module.";
    };

    enabledModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Model names from `services.llama-swap.modelCatalog` to expose through llama-swap.";
    };

    preloadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Subset of enabled models to preload when llama-swap starts.";
    };

    serviceEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables added to the llama-swap systemd service.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingModels == [ ];
        message = "Unknown llama-swap models: ${lib.concatStringsSep ", " missingModels}";
      }
      {
        assertion = unknownPreloads == [ ];
        message = "Preloaded llama-swap models must also be enabled: ${lib.concatStringsSep ", " unknownPreloads}";
      }
      {
        assertion = invalidGeneratedModels == [ ];
        message = "llama-swap models without `file` must provide `upstream.cmd`: ${lib.concatStringsSep ", " invalidGeneratedModels}";
      }
      {
        # Guard: the diarization server hardcodes the embedding-cache path.
        # If it disappears from tmpfiles or ReadWritePaths, startup fails with
        # OSError: [Errno 30] Read-only file system.
        assertion =
          let
            rules = config.systemd.tmpfiles.rules;
            rwPaths = config.systemd.services.llama-swap.serviceConfig.ReadWritePaths or [ ];
            hasTmpfile = builtins.any (
              r: builtins.match ".*${proxy.diarizationEmbeddingCache}.*" r != null
            ) rules;
            hasRwPath = builtins.elem proxy.diarizationEmbeddingCache rwPaths;
          in
          hasTmpfile && hasRwPath;
        message = "diarization embedding-cache (${proxy.diarizationEmbeddingCache}) must be in systemd.tmpfiles.rules and llama-swap ReadWritePaths";
      }
    ];

    environment.systemPackages = [ cfg.serverPackage ];

    services.llama-cpp.enable = lib.mkForce false;

    services.llama-swap = {
      port = lib.mkDefault 8080;
      listenAddress = lib.mkDefault "0.0.0.0";
      openFirewall = lib.mkDefault true;
      models = selectedModels;

      settings = {
        healthCheckTimeout = lib.mkDefault 60;
        logLevel = lib.mkDefault "info";
        logToStdout = lib.mkDefault "both";
        hooks.on_startup.preload = lib.mkDefault cfg.preloadModels;
        models = lib.mkDefault renderedModels;
      };
    };

    systemd.services.llama-swap.path = [ pkgs.lact ];
    systemd.services.llama-swap.environment = backendEnvironment // cfg.serviceEnvironment;

    systemd.tmpfiles.rules = [
      "d /srv/llama-swap 0755 root root - -"
      "d ${cfg.modelDirectory} 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d /srv/llama-swap/voices 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      # CacheDirectory creates /var/cache/llama-swap as root:root; re-own for service user so
      # HF_HOME and XDG_CACHE_HOME subdirectories are writable at runtime.
      "d /var/cache/llama-swap 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d /var/cache/llama-swap/huggingface 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d ${proxy.sharedFasterWhisperCache} 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d ${proxy.diarizationCache} 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d ${proxy.diarizationEnrollmentDir} 0750 ${cfg.modelOwner} ${cfg.modelGroup} - -"
      "d ${proxy.diarizationEmbeddingCache} 0750 ${cfg.modelOwner} ${cfg.modelGroup} - -"
    ];

    systemd.services.llama-swap.serviceConfig.ReadWritePaths = lib.mkAfter [
      proxy.sharedFasterWhisperCache
      proxy.diarizationCache
      proxy.diarizationEnrollmentDir
      proxy.diarizationEmbeddingCache
    ];
  };
}
