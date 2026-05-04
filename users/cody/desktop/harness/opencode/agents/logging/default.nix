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

  programs.opencode.agents.logging = ''
    ---
    description: read logs to understand issues.
    mode: subagent
    tools:
      "grafana_*": true
    permission:
      edit: deny
      "context7_*": deny
      "nixos-option-search_*": deny
    ---
    Use the Grafana tool to search the logs.
  '';
}
