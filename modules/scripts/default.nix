{ pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./bluetooth-switch.nix
    ./update.nix
    ./ai-doc-upload.nix
    ./transcription.nix
  ];

  scriptPackages = map (
    script: pkgs.callPackage (toString script) { inherit config pkgs; }
  ) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages =
    scriptPackages
    ++ (with pkgs; [
      openai-whisper
      sox
      xdotool
    ]);
}
