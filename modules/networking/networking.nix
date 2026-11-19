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
      # Enable the OpenSSH daemon with hardening
      services.openssh = {
        enable = true;
        # Keep listening on all interfaces for local LAN access
        # Hardening settings
        settings = {
          # Disable root login entirely
          PermitRootLogin = "no";
          # Limit authentication attempts
          MaxAuthTries = 3;
          # Keepalive settings to detect dead connections
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;
        };
      };

      # Enable fail2ban for ssh protection
      services.fail2ban.enable = true;

      # Enable nftables firewall
      networking.nftables.enable = true;

      # Every host manages its links with NetworkManager.
      networking.networkmanager.enable = true;

      # Tailscale mesh between hosts. To add a machine, run
      # "sudo tailscale up --auth-key=KEY" with a key generated at
      # https://login.tailscale.com/admin/machines/new-linux
      services.tailscale.enable = true;

      # Shared hostname mappings for Tailscale IPs
      networking.hosts = {
        ${hosts.beast.tailscale} = [ "beast" ];
      };
    };

  # Opt-in (nas): stricter fail2ban than the shared default above. Not included
  # by den.default; the server role includes it.
  den.aspects.networking.strict-fail2ban.nixos =
    { config, ... }:

    let
      inherit (config.codyos.site) lan;
    in
    {
      # Fail2ban
      services.fail2ban = {
        enable = true;
        # Ban IP after 5 failures
        maxretry = 5;
        ignoreIP = [
          # Whitelist LAN subnet
          lan.subnet
        ];
        bantime = "24h"; # Ban IPs for one day on the first ban
        bantime-increment = {
          enable = true; # Enable increment of bantime after each violation
          formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
          maxtime = "168h"; # Do not ban for more than 1 week
          overalljails = true; # Calculate the bantime based on all the violations
        };
      };
    };

  den.default.includes = [ den.aspects.networking ];
}
