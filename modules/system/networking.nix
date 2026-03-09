# Network security services

{ ... }:

{
  # Enable the OpenSSH daemon
  services.openssh.enable = true;

  # Enable fail2ban for ssh protection
  services.fail2ban.enable = true;

  # Enable nftables firewall
  networking.nftables.enable = true;
}
