{ pkgs, config, lib, ... }: {

  # Start the wallpaper service
  systemd.services.wallpaper = {
    enable = true;
    description = "Set a random wallpaper at regular intervals";
    wantedBy = [ "hyprland-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "wallpaper";
    };
  };

  # fstrim for SSDs
  services.fstrim.enable = true;

  # Microcode updates for Intel CPUs
  hardware.cpu.intel.updateMicrocode = true;

  #xdg  
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal
    ];
  };

  # Bluetooth and OpenRazer for RGB peripherals
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    openrazer.enable = true;
    openrazer.devicesOffOnScreensaver = true;
    openrazer.users = [ "codyt" ];
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true;
  };

  # Enable UPower because chrome said so...
  services.upower.enable = true;

  # Giving jellyfin access to my drives
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "codyt";
  };
}
