{ den, ... }:
{
  den.aspects = {
    nas.includes = [ den.aspects.networking.strict-fail2ban ];

    networking = {
      nixos =
        { config, ... }:
        {
          services = {
            openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "no";
                MaxAuthTries = 3;
                ClientAliveInterval = 300;
                ClientAliveCountMax = 2;
              };
            };
            fail2ban.enable = true;
            tailscale.enable = true;
          };
          networking = {
            nftables.enable = true;
            networkmanager.enable = true;
            hosts.${config.codyos.site.hosts.beast.tailscale} = [ "beast" ];
          };
        };

      strict-fail2ban.nixos =
        { config, ... }:
        {
          services.fail2ban = {
            enable = true;
            maxretry = 5;
            ignoreIP = [ config.codyos.site.lan.subnet ];
            bantime = "24h";
            bantime-increment = {
              enable = true;
              formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
              maxtime = "168h";
              overalljails = true;
            };
          };
        };
    };
  };

  den.default.includes = [ den.aspects.networking ];
}
