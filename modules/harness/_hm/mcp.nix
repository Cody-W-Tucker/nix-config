{ localAi }:
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
  hindsight = import ../../ai/_hindsight-endpoints.nix {
    nasTailscale = osConfig.codyos.site.hosts.nas.tailscale;
  };
  dejaEmbedding = {
    DEJA_EMBED_URL = "http://${
      if localAi then "127.0.0.1" else osConfig.codyos.site.hosts.nas.tailscale
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

  sops.secrets.karakeep-api-key = { };

  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      deja.command = lib.getExe dejaMcp;
      karakeep.command = lib.getExe karakeepMcp;
      # Use the same NAS index and GPU backend as Hermes, without exposing a
      # network listener. On the NAS itself, run QMD directly.
      qmd =
        if localAi then
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
        url = "${hindsight.api localAi}/mcp/";
      };
      exa = {
        url = "https://mcp.exa.ai/mcp";
      };
      context7.command = lib.getExe pkgs.context7-mcp;
      gh_grep = {
        url = "https://mcp.grep.app";
      };
      nixos-option-search.command = lib.getExe pkgs.mcp-nixos;
    };
  };

  # Pi uses the same MCP schema, without Home Manager's null/default fields.
  home.file."${config.programs.pi-coding-agent.configDir}/mcp.json".text = builtins.toJSON {
    mcpServers = lib.mapAttrs (
      _: server: lib.filterAttrs (_: value: value != null && value != [ ] && value != { }) server
    ) config.programs.mcp.servers;
  };
}
