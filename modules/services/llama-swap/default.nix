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
          type = lib.types.str;
          description = "GGUF file name inside the llama-swap model directory.";
        };

        alias = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Alias exposed by llama-server.";
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
      };
    }
  );

  defaultModelCatalog = import ./models.nix;

  defaultServerPackage =
    if cfg.acceleration == "rocm" then
      pkgs.callPackage ../../../packages/llama-cpp-strix.nix { }
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

  resolvedModelCatalog = lib.recursiveUpdate cfg.modelCatalog cfg.modelOverrides;

  missingModels = lib.filter (name: !(builtins.hasAttr name resolvedModelCatalog)) cfg.enabledModels;
  unknownPreloads = lib.filter (name: !(builtins.elem name cfg.enabledModels)) cfg.preloadModels;

  selectedModels = lib.filterAttrs (
    name: _: builtins.elem name cfg.enabledModels
  ) resolvedModelCatalog;

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
      ++ model.extraArgs
    );

  renderedModels = lib.mapAttrs (_: model: {
    cmd = mkModelCommand model;
    inherit (model) ttl;
  }) selectedModels;
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
    ];

    environment.systemPackages = [ cfg.serverPackage ];

    services.llama-cpp.enable = lib.mkForce false;

    services.llama-swap = {
      port = lib.mkDefault 8080;
      listenAddress = lib.mkDefault "0.0.0.0";
      openFirewall = lib.mkDefault true;

      settings = {
        healthCheckTimeout = lib.mkDefault 60;
        logLevel = lib.mkDefault "info";
        logToStdout = lib.mkDefault "both";
        hooks.on_startup.preload = lib.mkDefault cfg.preloadModels;
        models = lib.mkDefault renderedModels;
      };
    };

    systemd.services.llama-swap.environment = backendEnvironment // cfg.serviceEnvironment;

    systemd.tmpfiles.rules = [
      "d /srv/llama-swap 0755 root root - -"
      "d ${cfg.modelDirectory} 0755 ${cfg.modelOwner} ${cfg.modelGroup} - -"
    ];
  };
}
