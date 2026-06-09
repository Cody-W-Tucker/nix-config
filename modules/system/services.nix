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

  systemd.services.fwupd-refresh.serviceConfig = {
    User = lib.mkForce "root";
    ExecStart = lib.mkForce [
      ""
      # Running as the dedicated service user hits fwupd polkit auth in the
      # timer context, so use root for the non-interactive refresh.
      "${lib.getExe' pkgs.fwupd "fwupdmgr"} refresh"
    ];
  };

  # Include all firmware for devices like Bluetooth
  hardware.enableRedistributableFirmware = true;
}
