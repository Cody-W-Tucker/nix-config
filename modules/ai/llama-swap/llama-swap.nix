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
      # NAS intentionally tracks unstable llama-cpp 0.6.0 for SystemOne
      # (upstream PR #29818) while the host stays on stable pkgs. CUDA comes from
      # the host nixpkgs.config that pkgs.unstable inherits.
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
          # Every rendered argument is shell-escaped so values containing shell
          # metacharacters (notably the JSON --chat-template-kwargs value) pass
          # through to llama-server literally. ${PORT} keeps its literal form for
          # llama-swap's own template substitution, which still matches the
          # `${PORT}` substring inside the single quotes.
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
        # Keep the router on nixos-unstable alongside the llama.cpp server, so
        # decision-endpoint support can move forward with the upstream packages.
        package = pkgs.unstable.llama-swap;
        inherit (endpoint) port;
        listenAddress = "0.0.0.0";
        openFirewall = false;
        settings = {
          healthCheckTimeout = 60;
          logLevel = "info";
          logToStdout = "both";
          models = lib.mapAttrs (name: model: {
            cmd = llamaServerCommand name model;
            ttl = model.ttl or 600;
          }) (import ./_models.nix { inherit pkgs; });
          # Keep embeddings across workload changes. No set permits audio to share
          # the card with either chat model; models outside the sets run alone.
          routing.router = {
            use = "matrix";
            settings.matrix = {
              vars = matrixModels;
              sets = {
                summarization = "summary & embed";
                chat = "text & embed";
                audio = "stt & cleanup & tts & embed";
                # Laya's Vega fits beside embeddings, but not beside them and a chat model.
                classify = "vega & embed";
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
        # CacheDirectory creates /var/cache/llama-swap as root:root; re-own for service user so
        # HF_HOME and XDG_CACHE_HOME subdirectories are writable at runtime.
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
