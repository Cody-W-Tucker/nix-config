{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Runtime wrapper: injects the SOPS-backed Mealie API key into the
  # upstream mealie-mcp-server (uvx) invocation. The key is read from the
  # decrypted secret at runtime, so it never lands in the Nix store or the
  # static MCP config. The command itself is the upstream-documented
  # invocation and is client-neutral (any stdio MCP client could run it).
  mealieMcp = pkgs.writeShellApplication {
    name = "mealie-mcp";
    runtimeInputs = [
      pkgs.uv
      pkgs.git
      # Full interpreter on PATH so uvx discovers a Nix Python with
      # built-in zlib support.
      pkgs.python3
    ];
    text = ''
      export MEALIE_BASE_URL="https://mealie.homehub.tv"
      MEALIE_API_KEY="$(< ${config.sops.secrets."mealie-api-key".path})"
      export MEALIE_API_KEY
      exec ${pkgs.uv}/bin/uvx git+https://github.com/rldiao/mealie-mcp-server
    '';
  };
in
{
  config = {
    services.hermes-agent.mcpServers.mealie = {
      command = lib.getExe mealieMcp;
    };
  };
}
