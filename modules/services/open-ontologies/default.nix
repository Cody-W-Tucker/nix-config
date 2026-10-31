{ pkgs, self, ... }:
{
  systemd.services.open-ontologies = {
    description = "Shared Open Ontologies MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig = {
      RequiresMountsFor = "/mnt/knowledge";
      ConditionPathIsMountPoint = "/mnt/knowledge";
    };
    serviceConfig = {
      User = "codyt";
      Group = "users";
      UMask = "0077";
      ExecStart = "${
        self.packages.${pkgs.stdenv.hostPlatform.system}.open-ontologies
      }/bin/open-ontologies --data-dir /mnt/knowledge/.open-ontologies serve-http --host 127.0.0.1 --port 18081 --storage-mode persistent --tools-allow onto_status,onto_validate,onto_load,onto_query,onto_stats,onto_clear,onto_shacl,onto_vocab_check,onto_reason,onto_segment_retrieve";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Only Beast's Tailscale address may reach MCP. The server's other HTTP API
  # routes remain loopback-only; neither endpoint uses application credentials.
  services.nginx.virtualHosts."open-ontologies-tailnet" = {
    listen = [
      {
        addr = "0.0.0.0";
        port = 18082;
      }
    ];
    locations."= /mcp" = {
      proxyPass = "http://127.0.0.1:18081";
      # The global recommended headers also set Host; sending both is rejected
      # by the MCP transport's Host validation.
      recommendedProxySettings = false;
      extraConfig = ''
        allow 100.108.143.19;
        deny all;
        # MCP clients here do not send Origin; reject browser cross-origin calls.
        if ($http_origin != "") { return 403; }
        proxy_set_header Host 127.0.0.1:18081;
        proxy_buffering off;
        proxy_read_timeout 3600s;
      '';
    };
    locations."/".return = "404";
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 18082 ];
}
