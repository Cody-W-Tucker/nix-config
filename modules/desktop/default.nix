{ pkgs, ... }:

let
  kdenliveWithSpeechRuntime = pkgs.symlinkJoin {
    name = "kdenlive-with-speech-runtime";
    paths = [ pkgs.kdePackages.kdenlive ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/kdenlive" \
        --prefix PATH : "${
          pkgs.lib.makeBinPath [
            pkgs.python3
            pkgs.python3Packages.pip
          ]
        }" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc ]}"
    '';
  };
in

{
  imports = [
    ./audio
    ./hyprland.nix
    ./logging.nix
    ./printing.nix
    ../services/syncthing.nix
    ./hardware/razer.nix
    ./hardware/wifi.nix
    ./vpn
  ];

  hardware.graphics.enable = true;

  # Enable nix-ld for running non-Nix binaries (AppImages, downloaded binaries, etc.)
  programs.nix-ld.enable = true;

  services = {
    # Allows nautilus (gnome files) to access gvfs mounts (trash and samba shares)
    gvfs.enable = true;
    # Enable support for removable devices.
    udisks2.enable = true;
  };

  # Install basic desktop environment packages that I want on all my systems.
  environment.systemPackages = with pkgs; [
    # list of stable packages go here
    pavucontrol # PulseAudio volume control
    xdg-utils # xdg-open
    usbutils # For listing USB devices
    udiskie # For mounting USB devices
    seahorse # GNOME keyring manager
    kdenliveWithSpeechRuntime # Video editor; speech tools are configured from inside Kdenlive
  ];

  networking.firewall = {
    allowedTCPPorts = [
      8384 # Syncthing GUI
      22000 # Syncthing sync protocol
    ];
    allowedUDPPorts = [
      22000 # Syncthing sync protocol
      21027 # Syncthing local discovery
    ];
    # Open firewall ports for KDE Connect discovery
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };
}
