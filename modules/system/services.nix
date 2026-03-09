# Core system services

{ ... }:

{
  # Enables prompts to install missing packages when running commands
  programs.command-not-found.enable = true;

  # Logrotate
  services.logrotate.enable = true;

  # Firmware updates
  services.fwupd.enable = true;

  # Include all firmware for devices like Bluetooth
  hardware.enableRedistributableFirmware = true;
}
