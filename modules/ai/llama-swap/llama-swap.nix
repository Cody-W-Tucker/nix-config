{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.llama-swap ];

  den.aspects.llama-swap.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      endpoint = import ./_endpoint.nix;
      user = config.codyos.site.user.name;
      group = "users";
      llamaCpp = pkgs.unstable.llama-cpp;

      llamaServerCommand =
        name: model:
        let
          m = {
            alias = name;
            mmprojFile = null;
            contextSize = 65536;
            batchSize = 2048;
            ubatchSize = 1024;
            threads = 6;
            gpuLayers = null;
            flashAttention = true;
            extraArgs = [ ];
          }
          // model;
          escape = lib.strings.escapeShellArg;
        in
        lib.concatStringsSep " " (
          [
            (escape (lib.getExe' llamaCpp "llama-server"))
            "--port"
            (escape "\${PORT}")
            "-m"
            (escape "${m.file}")
            "--alias"
            (escape m.alias)
            "--no-webui"
            "--flash-attn"
            (escape (if m.flashAttention then "on" else "off"))
          ]
          ++ lib.optionals (m.gpuLayers != null) [
            "--n-gpu-layers"
            (escape (toString m.gpuLayers))
          ]
          ++ [
            "-c"
            (escape (toString m.contextSize))
            "-b"
            (escape (toString m.batchSize))
            "-ub"
            (escape (toString m.ubatchSize))
            "-t"
            (escape (toString m.threads))
          ]
          ++ lib.optionals (m.mmprojFile != null) [
            "--mmproj"
            (escape "${m.mmprojFile}")
          ]
          ++ map escape m.extraArgs
        );

      matrixModels = {
        summary = "qwen-3.5-4b";
        text = "qwen-3.5-9b";
        embed = "qwen3-embedding-0.6b";
        stt = "fluid-speech-pro-clean";
        cleanup = "s1-mini";
        tts = "kokoro-82m";
        vega = "vega";
      };
    in
    {
      imports = [
        ./_audio.nix
        ./_laya.nix
        ./_classifiers.nix
      ];

      services.llama-swap = {
        enable = true;
        package = pkgs.unstable.llama-swap;
        inherit (endpoint) port;
        listenAddress = "0.0.0.0";
        settings = {
          healthCheckTimeout = 60;
          logLevel = "info";
          logToStdout = "both";
          models = lib.mapAttrs (name: model: {
            cmd = llamaServerCommand name model;
            ttl = model.ttl or 600;
          }) (import ./_models.nix { inherit pkgs; });
          routing.router = {
            use = "matrix";
            settings.matrix = {
              vars = matrixModels;
              sets = {
                summarization = "summary & embed & vega";
                chat = "text & embed & vega";
                audio = "stt & cleanup & tts & embed & vega";
              };
            };
          };
        };
      };

      environment.systemPackages = [ llamaCpp ];

      systemd.services.llama-swap = {
        environment = {
          HF_HOME = "/var/cache/llama-swap/huggingface";
          XDG_CACHE_HOME = "/var/cache/llama-swap";
          LD_LIBRARY_PATH = lib.concatStringsSep ":" [
            "/run/opengl-driver/lib"
            "/run/current-system/sw/lib"
          ];
        };
        serviceConfig = {
          CacheDirectory = "llama-swap";
          ProcSubset = lib.mkForce "all";
          ProtectProc = lib.mkForce "default";
          DynamicUser = lib.mkForce false;
          User = user;
          Group = group;
        };
      };

      systemd.tmpfiles.rules = [
        "d /var/cache/llama-swap 0755 ${user} ${group} - -"
        "d /var/cache/llama-swap/huggingface 0755 ${user} ${group} - -"
      ];

      codyos.homepage.cards.LlamaSwap = {
        group = "Business";
        order = 30;
        card = {
          href = "http://${endpoint.host}:${toString endpoint.port}";
          icon = "ollama";
          description = "LLM Model Router";
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        endpoint.port
        endpoint.speechHistoryPort
      ];

      nas.backups.sqlite = [
        {
          name = "speech-history";
          source = "/var/lib/llama-swap/speech-history/history.sqlite";
        }
        {
          name = "laya-labels";
          source = "/var/lib/laya/labels.sqlite";
        }
      ];
    };
}
