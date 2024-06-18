{ pkgs, config, lib, ... }: {

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };
  services.printing.drivers = [ pkgs.cnijfilter2 ];

  # environment.systemPackages = with pkgs; [
  #   system-config-printer
  # ];
}
