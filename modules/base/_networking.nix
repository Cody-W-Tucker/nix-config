# Network security services

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
}
