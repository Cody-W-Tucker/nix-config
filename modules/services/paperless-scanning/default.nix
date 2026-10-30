{ config, pkgs, ... }:
let
  scan = pkgs.writeShellScript "paperless-scan" ''
    set -eu
    umask 077
    # Keep the working directory and page images if scanning or conversion fails.
    work=$(mktemp -d /var/lib/paperless-scanning/scan-XXXXXXXX)
    cd "$work"
    scanadf -d "$SCANBD_DEVICE" --source "ADF Duplex" --mode Color --resolution 300dpi --swcrop=yes
    ${pkgs.imagemagick}/bin/convert image* -density 300 scan.pdf
    test -s scan.pdf
    name="Scan-$(date +%Y%m%d-%H%M%S)-''${work##*-}.pdf"
    mv scan.pdf "/var/lib/paperless-scanning/pending/$name"
    rm -f image*
    cd /
    rmdir "$work"
  '';
  deliver = pkgs.writeShellScript "paperless-scan-deliver" ''
    set -eu
    umask 077
    pending=/var/lib/paperless-scanning/pending
    destination=/mnt/paperless-consume
    exec 9> /var/lib/paperless-scanning/delivery.lock
    flock -n 9 || exit 0
    for file in "$pending"/*.pdf; do
      [ -f "$file" ] || continue
      # Trigger the automount and refuse to write into an unmounted directory.
      ls "$destination" >/dev/null
      mountpoint -q "$destination" || exit 1
      name=''${file##*/}
      cp "$file" "$destination/$name.tmp"
      mv "$destination/$name.tmp" "$destination/$name"
      rm "$file"
    done
  '';
  tools = [
    pkgs.coreutils
    pkgs.util-linux
    pkgs.sane-frontends
    pkgs.imagemagick
    pkgs.ghostscript
  ];
  scanbdConf = pkgs.writeText "scanbd.conf" ''
    global {
      debug = true
      debug-level = 3
      user = scanner
      group = scanner
      scriptdir = /etc/scanbd/scripts
      pidfile = /run/scanbd.pid
      timeout = 500
      environment {
        device = "SCANBD_DEVICE"
        action = "SCANBD_ACTION"
      }
      multiple_actions = true
      action scan {
        filter = "^scan.*"
        numerical-trigger {
          from-value = 1
          to-value = 0
        }
        desc = "Scan to Paperless"
        script = "scan.script"
      }
    }
  '';
in
{
  hardware.sane.enable = true;

  users.users.scanner = {
    isSystemUser = true;
    uid = config.ids.uids.scanner;
    group = "scanner";
    extraGroups = [ "lp" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/paperless-scanning 0700 scanner scanner -"
    "d /var/lib/paperless-scanning/pending 0700 scanner scanner -"
  ];

  environment.etc."scanbd/scanbd.conf".source = scanbdConf;
  environment.etc."scanbd/scripts/scan.script".source = scan;

  systemd.services.scanbd = {
    description = "ScanSnap button polling";
    wantedBy = [ "multi-user.target" ];
    path = tools;
    environment = {
      SANE_CONFIG_DIR = "/etc/sane-config";
      LD_LIBRARY_PATH = "/etc/sane-libs";
      HOME = "/var/lib/paperless-scanning";
    };
    serviceConfig = {
      ExecStart = "${pkgs.scanbd}/bin/scanbd -c /etc/scanbd/scanbd.conf -f";
      Restart = "on-failure";
    };
  };

  systemd.services.paperless-scan-delivery = {
    description = "Deliver queued scans to Paperless";
    path = tools;
    serviceConfig = {
      Type = "oneshot";
      User = "scanner";
      Group = "scanner";
      ExecStart = deliver;
    };
  };
  systemd.timers.paperless-scan-delivery = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitInactiveSec = "1min";
    };
  };
}
