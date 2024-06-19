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

  # Enable CUPS to print documents.
  services.printing.enable = true;
}
