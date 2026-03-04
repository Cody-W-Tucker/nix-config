{ inputs, pkgs, ... }:

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    # Quick Markdown Search (QMD)
    inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.qmd
  ];
}
