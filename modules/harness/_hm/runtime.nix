{
  inputs,
  lib,
  pkgs,
}:
let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) rtk;
  tools = with pkgs; [
    bash
    coreutils
    diffutils
    direnv
    findutils
    gawk
    git
    gnugrep
    gnused
    jq
    nix
    nix-diff
    nodejs
    nvd
    python3
    ripgrep
    rtk
  ];
  bashExe = lib.getExe pkgs.bash;
  direnvExe = lib.getExe pkgs.direnv;
  run = pkgs.writeShellScript "agent-project-shell" ''
    export PATH=${lib.makeBinPath tools}''${PATH:+:"$PATH"}
    exec ${direnvExe} exec . ${bashExe} --noprofile --norc "$@"
  '';
in
# Harnesses use the basename to decide which shell syntax to generate.
lib.getExe (
  pkgs.writeShellScriptBin "bash" ''
    # Shell detection must still work when the working directory has a blocked .envrc.
    case "''${1-}" in
      --version|--help) exec ${bashExe} "$@" ;;
    esac
    # Unload any environment inherited from the launching terminal before setting
    # the baseline PATH. direnv exec does not change the working directory.
    if [[ -n ''${DIRENV_DIFF-} ]]; then
      exec ${direnvExe} exec ${builtins.storeDir} ${run} "$@"
    fi
    exec ${run} "$@"
  ''
)
