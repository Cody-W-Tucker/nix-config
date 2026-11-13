{
  osConfig,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
  dejaEmbedding = {
    DEJA_EMBED_URL = "http://${
      if osConfig.networking.hostName == "nas" then
        "127.0.0.1"
      else
        osConfig.codyos.site.hosts.nas.tailscale
    }:8081/v1/embeddings";
    DEJA_EMBED_MODEL = "qwen3-embedding-0.6b";
    DEJA_EMBED_QUERY_PREFIX = "Instruct: Given a search query, retrieve relevant passages that answer the query\nQuery: ";
  };
  dejaMcp = pkgs.writeShellApplication {
    name = "deja-mcp";
    runtimeInputs = [ pkgs.sqlite ];
    text = ''
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") dejaEmbedding
      )}
      exec ${lib.getExe deja} mcp
    '';
  };
  grafanaMcp = pkgs.writeShellApplication {
    name = "grafana-mcp";
    text = ''
      export GRAFANA_URL="https://monitoring.${osConfig.codyos.site.domain}"
      GRAFANA_SERVICE_ACCOUNT_TOKEN="$(< ${config.sops.secrets.grafana-mcp-token.path})"
      export GRAFANA_SERVICE_ACCOUNT_TOKEN
      exec ${pkgs.mcp-grafana}/bin/mcp-grafana "$@"
    '';
  };
  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.${osConfig.codyos.site.domain}"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY
      exec npx -y @karakeep/mcp "$@"
    '';
  };
in
{
  home.sessionVariables = dejaEmbedding;

  sops.secrets.grafana-mcp-token = { };
  sops.secrets.karakeep-api-key = { };

  programs.opencode.settings.mcp.servers = {
    grafana = {
      type = "local";
      command = [ "${grafanaMcp}/bin/grafana-mcp" ];
    };
    karakeep = {
      type = "local";
      command = [ "${karakeepMcp}/bin/karakeep-mcp" ];
    };
  };

  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      deja.command = lib.getExe dejaMcp;
      # Use the same NAS index and GPU backend as Hermes, without exposing a
      # network listener. On the NAS itself, run QMD directly.
      qmd =
        if osConfig.networking.hostName == "nas" then
          {
            command = lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
            args = [ "mcp" ];
            env = {
              QMD_LLAMA_GPU = "vulkan";
              VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
            };
          }
        else
          {
            command = lib.getExe pkgs.openssh;
            args = [
              "-T"
              "-o"
              "BatchMode=yes"
              "nas"
              "env QMD_LLAMA_GPU=vulkan VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json qmd mcp"
            ];
          };
      hindsight = {
        type = "remote";
        url =
          if osConfig.networking.hostName == "nas" then
            "http://127.0.0.1:8888/mcp/"
          else
            "http://${osConfig.codyos.site.hosts.nas.tailscale}:18083/mcp/";
      };
      exa = {
        type = "remote";
        url = "https://mcp.exa.ai/mcp";
      };
      context7.command = lib.getExe pkgs.context7-mcp;
      gh_grep = {
        type = "remote";
        url = "https://mcp.grep.app";
      };
      nixos-option-search.command = lib.getExe pkgs.mcp-nixos;
    };
  };
}
