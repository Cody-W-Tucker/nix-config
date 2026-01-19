{ pkgs, ... }:

{
  # Enable sound with pipewire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true; # Required for priority rules in host specific configs
  };
  # Enable rtkit for real-time scheduling for audio
  security.rtkit.enable = true;

  # Ensure headset doesn't switch profiles
  services.pipewire.wireplumber.extraConfig."11-bluetooth-policy" = {
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };
  };

  # Bluetooth support
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          FastConnectable = true; # Improve connection speed
          JustWorksRepairing = "always";
          ControllerMode = "bredr"; # Allow low energy mode?
          MultiProfile = "multiple"; # Allow multiple profiles
        };
      };
    };
  };
  # Bluetooth audio support
  services.blueman.enable = true;

  # Bluetooth applet for Waybar
  services.blueman-applet.enable = true; # Bluetooth manager
}
