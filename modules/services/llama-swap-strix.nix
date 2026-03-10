# llama-swap with Strix Halo (gfx1151) optimized llama.cpp
# Provides on-demand model loading with automatic unloading

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-swap-strix;

  # Import the Strix-optimized llama-cpp package
  llama-cpp-strix = pkgs.callPackage ../../packages/llama-cpp-strix.nix { };
  llama-server = lib.getExe' llama-cpp-strix "llama-server";

  # Default model directory
  defaultModelDir = "/var/lib/llama-cpp/models";
in
{
  options.services.llama-swap-strix = {
    enable = lib.mkEnableOption "llama-swap with Strix-optimized llama.cpp";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for llama-swap to listen on.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address for llama-swap to listen on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the firewall for llama-swap.";
    };

    modelDir = lib.mkOption {
      type = lib.types.path;
      default = defaultModelDir;
      description = "Directory containing GGUF model files.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            file = lib.mkOption {
              type = lib.types.str;
              description = "GGUF filename in modelDir.";
            };
            ttl = lib.mkOption {
              type = lib.types.ints.positive;
              default = 600;
              description = "Time in seconds before auto-unloading idle model.";
            };
            aliases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Alternative names for this model (e.g., OpenAI model names).";
            };
          };
        }
      );
      default = { };
      description = "Attribute set of model configurations.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Model to preload on startup.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags passed to llama-server.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable upstream llama-swap module with our configuration
    services.llama-swap = {
      enable = true;
      inherit (cfg) port listenAddress openFirewall;

      settings = {
        logLevel = "info";
        logToStdout = "both";
        healthCheckTimeout = 60;

        models = lib.mapAttrs (name: modelCfg: {
          cmd = "${llama-server} --port \${PORT} -m ${cfg.modelDir}/${modelCfg.file} --alias ${name} --no-webui --flash-attn on --no-mmap -ngl 999 ${lib.concatStringsSep " " cfg.extraFlags}";
          inherit (modelCfg) ttl aliases;
        }) cfg.models;

        hooks = lib.optionalAttrs (cfg.defaultModel != null) {
          on_startup.preload = [ cfg.defaultModel ];
        };
      };
    };

    # Create model directory with proper permissions for llama-swap user
    systemd.tmpfiles.rules = [
      "d ${cfg.modelDir} 0755 llama-swap llama-swap -"
    ];

    # Allow llama-swap service to access model directory despite sandboxing
    systemd.services.llama-swap.serviceConfig = {
      ReadWritePaths = [ cfg.modelDir ];
      # Required for GPU access with ROCm
      PrivateDevices = lib.mkForce false;
    };

    # Environment variables for ROCm/HIP
    environment.sessionVariables = {
      HSA_OVERRIDE_GFX_VERSION = "11.5.1";
      ROCM_PATH = "${pkgs.rocmPackages.rocm-core}";
      HIP_PATH = "${pkgs.rocmPackages.rocm-core}";
    };

    # Disable the direct llama-cpp service to avoid conflicts
    services.llama-cpp.enable = lib.mkForce false;
  };
}
