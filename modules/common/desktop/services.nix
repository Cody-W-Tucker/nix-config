{ pkgs, config, lib, ... }:{

  # Bluetooth and OpenRazer for RGB peripherals
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
}
