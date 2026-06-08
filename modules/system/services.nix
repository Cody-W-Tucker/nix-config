# Core system services

{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  # Enables prompts to install missing packages when running commands
  programs.command-not-found = {
    enable = true;
    dbPath =
      lib.mkForce
        inputs.flake-programs-sqlite.packages.${pkgs.stdenv.hostPlatform.system}.programs-sqlite;
  };

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

  systemd.services.fwupd-refresh.serviceConfig.ExecStart = lib.mkForce [
    ""
    # The timer runs as a system user with no desktop polkit agent, so the
    # default interactive auth path fails even though a manual desktop refresh works.
    "${lib.getExe' pkgs.fwupd "fwupdmgr"} refresh --no-authenticate"
  ];

  # Include all firmware for devices like Bluetooth
  hardware.enableRedistributableFirmware = true;
}
