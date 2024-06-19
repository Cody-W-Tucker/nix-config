{ pkgs, config, lib, ... }: {

  # Bluetooth and OpenRazer for RGB peripherals
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Enable sound with pipewire.
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
}
