{
  # Small command-line tools every host's user gets, and the default $VISUAL.
  den.aspects.user-cli-tools.homeManager =
    { pkgs, ... }:
    {
      home = {
        packages = with pkgs; [
          fastfetch
          fd
          tree
          unzip
          zip
        ];
        sessionVariables = {
          VISUAL = "nvim";
        };
      };

      programs.ripgrep.enable = true;
    };
}
