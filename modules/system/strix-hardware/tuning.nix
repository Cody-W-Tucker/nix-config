# Strix Halo performance tuning module
# Provides tuned accelerator profile for AI workloads
{ pkgs, ... }:
{
  services.tuned = {
    enable = true;
    profiles = {
      strix-halo = {
        main = {
          include = "accelerator-performance";
        };
      };
    };
  };

  systemd.services.tuned-set-profile = {
    description = "Set TuneD profile for Strix Halo";
    after = [ "tuned.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.tuned}/bin/tuned-adm profile accelerator-performance";
    };
  };
}
