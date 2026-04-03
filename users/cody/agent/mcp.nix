{ pkgs, config, ... }:
let
  grafanaMcpWrapper = pkgs.writeShellScriptBin "grafana-mcp-wrapper" ''
    export GRAFANA_URL="https://monitoring.homehub.tv"
    export GRAFANA_SERVICE_ACCOUNT_TOKEN=$(cat ${config.sops.secrets.grafana-mcp-token.path})
    exec ${pkgs.mcp-grafana}/bin/mcp-grafana
  '';
in
{
  sops.secrets.grafana-mcp-token = { };

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
        command = "${grafanaMcpWrapper}/bin/grafana-mcp-wrapper";
      };
    };
  };
}
