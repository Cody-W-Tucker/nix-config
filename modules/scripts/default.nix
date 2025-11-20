{ config, pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./bluetooth-switch.nix
    ./update.nix
    ./ai-doc-upload.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;

  transcriptionPackage = pkgs.callPackage ./transcription.nix { inherit config pkgs; };
in

{
  # Adding the scripts to the system packages
  environment.systemPackages =
    scriptPackages
    ++ [ transcriptionPackage ]
    ++ (with pkgs; [
      openai-whisper
      sox
      xdotool
      cudatoolkit
    ]);
}
