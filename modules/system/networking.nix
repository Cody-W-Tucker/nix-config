# Network security services

{ ... }:

{
  # Enable the OpenSSH daemon with hardening
  services.openssh = {
    enable = true;
    # Keep listening on all interfaces for local LAN access
    # Hardening settings
    settings = {
      # Disable password authentication - keys only
      PasswordAuthentication = false;
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
}
