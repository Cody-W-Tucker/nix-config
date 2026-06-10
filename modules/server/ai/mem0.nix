{
  config,
  pkgs,
  self,
  ...
}:

let
  mem0Mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.mem0-mcp;
in
{
  environment.systemPackages = [ mem0Mcp ];

  systemd.tmpfiles.rules = [
    "d /var/lib/mem0 2770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} - -"
  ];
}
