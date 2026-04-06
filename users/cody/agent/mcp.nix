{ pkgs, config, ... }:
let
  grafanaMcp = pkgs.writeShellApplication {
    name = "grafana-mcp";
    text = ''
      export GRAFANA_URL="https://monitoring.homehub.tv"
      GRAFANA_SERVICE_ACCOUNT_TOKEN="$(< ${config.sops.secrets.grafana-mcp-token.path})"
      export GRAFANA_SERVICE_ACCOUNT_TOKEN

      exec ${pkgs.mcp-grafana}/bin/mcp-grafana "$@"
    '';
  };

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
in
{
  sops.secrets.grafana-mcp-token = { };
  sops.secrets.karakeep-api-key = { };

  programs.mcp = {
    enable = true;
    servers = {
      # docs-langchain = {
      #   url = "https://docs.langchain.com/mcp";
      # };
      context7 = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @upstash/context7-mcp"
        ];
      };
      nixos-option-search = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };
      grafana = {
        command = "${grafanaMcp}/bin/grafana-mcp";
      };
      karakeep = {
        command = "${karakeepMcp}/bin/karakeep-mcp";
      };
    };
  };
}
