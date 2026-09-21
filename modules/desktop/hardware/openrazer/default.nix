# Beast-only Razer lighting: OpenRazer daemon + Polychromatic UI.
# NixOS hardware.openrazer does not expose restore_persistence, so we
# replace the user-unit ExecStart with a config that includes it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.openrazer;
  toPyBoolStr = b: if b then "True" else "False";
  daemonConfFile = pkgs.writeText "razer.conf" ''
    [General]
    verbose_logging = ${toPyBoolStr cfg.verboseLogging}

    [Startup]
    sync_effects_enabled = ${toPyBoolStr cfg.syncEffectsEnabled}
    devices_off_on_screensaver = ${toPyBoolStr cfg.devicesOffOnScreensaver}
    battery_notifier = ${toPyBoolStr cfg.batteryNotifier.enable}
    battery_notifier_freq = ${toString cfg.batteryNotifier.frequency}
    battery_notifier_percent = ${toString cfg.batteryNotifier.percentage}
    restore_persistence = True

    [Statistics]
    key_statistics = ${toPyBoolStr cfg.keyStatistics}
  '';
in
{
  hardware.openrazer = {
    enable = true;
    users = [ "codyt" ];
    syncEffectsEnabled = true;
  };

  environment.systemPackages = [ pkgs.polychromatic ];

  systemd.user.services.openrazer-daemon.serviceConfig.ExecStart =
    lib.mkForce "${cfg.packages.daemon}/bin/openrazer-daemon --config ${daemonConfFile} --foreground";
}
