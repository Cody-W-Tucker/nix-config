{
  config,
  pkgs,
  self,
  ...
}:

let
  mem0Http = self.packages.${pkgs.stdenv.hostPlatform.system}.mem0-http;
  mem0Mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.mem0-mcp;
in
{
  environment.systemPackages = [
    mem0Http
    mem0Mcp
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/mem0 2770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} - -"
  ];

  systemd.services.mem0-http = {
    description = "Local Mem0-compatible HTTP API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    wants = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${mem0Http}/bin/mem0-http";
      Restart = "always";
      RestartSec = 5;
      User = config.services.hermes-agent.user;
      Group = config.services.hermes-agent.group;
      UMask = "0007";
      StateDirectory = "mem0";
      WorkingDirectory = "/var/lib/mem0";
    };
  };
}
