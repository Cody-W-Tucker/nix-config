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
    nodejs
    python3
    ripgrep
    rtk
  ];
  bash = lib.getExe pkgs.bash;
  direnv = lib.getExe pkgs.direnv;
  run = pkgs.writeShellScript "agent-project-shell" ''
    export PATH=${lib.makeBinPath tools}''${PATH:+:"$PATH"}
    exec ${direnv} exec . ${bash} --noprofile --norc "$@"
  '';
in
# Harnesses use the basename to decide which shell syntax to generate.
lib.getExe (
  pkgs.writeShellScriptBin "bash" ''
    # Shell detection must still work when the working directory has a blocked .envrc.
    case "''${1-}" in
      --version|--help) exec ${bash} "$@" ;;
    esac
    # Unload any environment inherited from the launching terminal before setting
    # the baseline PATH. direnv exec does not change the working directory.
    if [[ -n ''${DIRENV_DIFF-} ]]; then
      exec ${direnv} exec ${builtins.storeDir} ${run} "$@"
    fi
    exec ${run} "$@"
  ''
)
