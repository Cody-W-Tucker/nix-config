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
in
{
  sops.secrets.grafana-mcp-token = { };

  programs.opencode.settings = {
    mcp.grafana = {
      type = "local";
      command = [ "${grafanaMcp}/bin/grafana-mcp" ];
      enabled = true;
    };

    tools."grafana_*" = false;
  };

  programs.opencode.agents.grafana = ''
    ---
    description: use the grafana mcp agent whenever you need to manage Grafana operations.
    mode: subagent
    tools:
      "grafana_*": true
    permission:
      edit: deny
      "context7_*": deny
      "nixos-option-search_*": deny
    ---
  '';
}
