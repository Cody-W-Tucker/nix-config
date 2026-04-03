# Core system services

{ ... }:

{
  # Enables prompts to install missing packages when running commands
  programs.command-not-found.enable = true;

  services = {
    # Logrotate
    logrotate.enable = true;

    # Firmware updates
    fwupd.enable = true;

    prometheus.exporters.smartctl = {
      enable = true;
      openFirewall = true;
      user = "root";
      group = "root";
    };
  };

  # Include all firmware for devices like Bluetooth
  hardware.enableRedistributableFirmware = true;
}
