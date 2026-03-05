{ inputs, pkgs, ... }:

let
  desloppify = pkgs.python3Packages.buildPythonPackage rec {
    pname = "desloppify";
    version = "0.7.7";
    format = "wheel";
    src = pkgs.fetchPypi {
      inherit pname version format;
      python = "py3";
      platform = "any";
      sha256 = "18f5pmqp98r06fba5yamc3bwf423b5fmvg6d63970ykm5564922q";
    };
    propagatedBuildInputs = with pkgs.python3Packages; [
      # Add dependencies here if needed
    ];
  };
in
{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    qmd # Semantic search
    coderabbit-cli
    rtk # Token reducer for command-line tools
    openspec # Spec driven development tool
    ck # Semantic search for code
    desloppify
  ];
}
