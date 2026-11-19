{
  den.aspects.hermes-voice-client.provides.to-users.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      voice = import ./_voice/client.nix { inherit config lib pkgs; };
      repair = pkgs.writeShellApplication {
        name = "hermes-waybar-repair";
        text = ''
          exec ${lib.getExe voice} cleanup
        '';
      };
    in
    {
      sops.secrets."hermes" = { };
      home.packages = [ repair ];
    };
}
