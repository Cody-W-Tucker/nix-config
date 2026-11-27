{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.networking.strict-fail2ban ];

  den.aspects.networking.nixos =
    { config, ... }:
    let
      inherit (config.codyos.site) hosts;
    in
    {
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          MaxAuthTries = 3;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;
        };
      };
      services.fail2ban.enable = true;
      networking.nftables.enable = true;
      networking.networkmanager.enable = true;
      services.tailscale.enable = true;
      networking.hosts = {
        ${hosts.beast.tailscale} = [ "beast" ];
      };
    };

  den.aspects.networking.strict-fail2ban.nixos =
    { config, ... }:

    let
      inherit (config.codyos.site) lan;
    in
    {
      services.fail2ban = {
        enable = true;
        maxretry = 5;
        ignoreIP = [
          lan.subnet
        ];
        bantime = "24h";
        bantime-increment = {
          enable = true;
          formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
          maxtime = "168h";
          overalljails = true;
        };
      };
    };
  den.default.includes = [ den.aspects.networking ];
}
