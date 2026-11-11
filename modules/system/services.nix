# Core system services

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  # Enables prompts to install missing packages when running commands
  # The flake's own package is keyed to its single nixpkgs input, so call its
  # builder with this host's nixpkgs revision (stable on nas, unstable on beast).
  programs.command-not-found = {
    enable = true;
    dbPath = lib.mkForce (
      pkgs.callPackage "${inputs.flake-programs-sqlite}/programs-sqlite.nix" {
        nixpkgsRev = config.system.nixos.revision;
      }
    );
  };

  services = {
    # Logrotate
    logrotate.enable = true;

    # Firmware updates
    fwupd.enable = true;

    prometheus.exporters.smartctl = {
      enable = true;
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

  # smartctl exporter: scraped by the NAS Prometheus over Tailscale (localhost on the NAS).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.smartctl.port
  ];

  # Include all firmware for devices like Bluetooth
  hardware.enableRedistributableFirmware = true;
}
