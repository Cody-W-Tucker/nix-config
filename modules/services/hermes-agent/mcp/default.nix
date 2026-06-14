{
  config,
  pkgs,
  self,
  ...
}:

let
  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.homehub.tv"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY

      exec npx -y @karakeep/mcp "$@"
    '';
  };

  minifluxMcp = pkgs.buildGoModule rec {
    pname = "miniflux-mcp";
    version = "unstable-2025-11-25";

    src = pkgs.fetchFromGitHub {
      owner = "tssujt";
      repo = "miniflux-mcp";
      rev = "793ed2198eddfdb4efc8163251e70091425909a2";
      hash = "sha256-OQKQYH7ZtTQh0BJfQzsgVRQoMnfFXwrCi3Q8hbCiBdY=";
    };

    vendorHash = "sha256-K7Gg65q/XOFu8wHKiyPIHKoF13GcIL3TICrQ0mh+HcQ=";
    subPackages = [ "." ];

    meta = {
      description = "Writable MCP server for Miniflux";
      homepage = "https://github.com/tssujt/miniflux-mcp";
      license = pkgs.lib.licenses.mit;
      mainProgram = "miniflux-mcp";
    };
  };

  minifluxMcpWrapped = pkgs.writeShellApplication {
    name = "miniflux-mcp";
    text = ''
      export MINIFLUX_URL="https://rss.homehub.tv"
      MINIFLUX_API_KEY="$(< ${config.sops.secrets."miniflux/API_KEY".path})"
      export MINIFLUX_API_KEY

      exec ${minifluxMcp}/bin/miniflux-mcp "$@"
    '';
  };
in
{
  config = {
    sops.secrets = {
      "karakeep-api-key" = {
        owner = config.services.hermes-agent.user;
        inherit (config.services.hermes-agent) group;
        mode = "0440";
      };
      "miniflux/API_KEY" = {
        owner = config.services.hermes-agent.user;
        inherit (config.services.hermes-agent) group;
        mode = "0440";
      };
    };

    services.hermes-agent = {
      mcpServers.karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
      mcpServers.miniflux.command = "${minifluxMcpWrapped}/bin/miniflux-mcp";
    };
  };
}
