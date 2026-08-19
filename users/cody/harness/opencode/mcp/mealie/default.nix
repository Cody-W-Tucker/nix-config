{
  pkgs,
  config,
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
    ];
    text = ''
      export MEALIE_BASE_URL="https://mealie.homehub.tv"
      export MEALIE_API_KEY="$(< ${config.sops.secrets."mealie-api-key".path})"
      exec ${pkgs.uv}/bin/uvx git+https://github.com/rldiao/mealie-mcp-server
    '';
  };
in
{
  # SOPS secret consumed by the wrapper above. Resolved from the private
  # nixos-secrets flake's home sops file (same source as opencode-api-key).
  sops.secrets."mealie-api-key" = { };

  programs.opencode.settings = {
    mcp.mealie = {
      type = "local";
      command = [ "${mealieMcp}/bin/mealie-mcp" ];
      enabled = true;
    };
  };
}
