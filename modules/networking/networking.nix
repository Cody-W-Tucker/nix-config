{ den, ... }:
{
  # Network security services: hardened OpenSSH, fail2ban, nftables, NetworkManager,
  # Tailscale and the shared Tailscale hostname mapping.
  den.aspects.networking.nixos =
    { config, ... }:
    let
      inherit (config.codyos.site) hosts;
    in
    {
      services.openssh = {
        enable = true;
        # Keep listening on all interfaces for local LAN access
        settings = {
          PermitRootLogin = "no";
          MaxAuthTries = 3;
          # Keepalive settings to detect dead connections
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;
        };
      };
      services.fail2ban.enable = true;
      networking.nftables.enable = true;
      networking.networkmanager.enable = true;
      # Tailscale mesh between hosts. To add a machine, run
      # "sudo tailscale up --auth-key=KEY" with a key generated at
      # https://login.tailscale.com/admin/machines/new-linux
      services.tailscale.enable = true;
      networking.hosts = {
        ${hosts.beast.tailscale} = [ "beast" ];
      };
    };

  # Opt-in (nas): stricter fail2ban than the shared default above. Not included
  # by den.default; nas includes it.
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
          overalljails = true; # Calculate the bantime based on all the violations
        };
      };
    };
  den.default.includes = [ den.aspects.networking ];
}
