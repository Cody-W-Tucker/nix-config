{ pkgs, config, inputs, gtkThemeFromScheme, ... }:

{
  apply-hm-env = pkgs.writeShellScript "apply-hm-env" ''
    ${lib.optionalString (config.home.sessionPath != []) ''
      export PATH=${builtins.concatStringsSep ":" config.home.sessionPath}:$PATH
    ''}
    ${builtins.concatStringsSep "\n" (
      lib.mapAttrsToList (k: v: ''
        export ${k}=${toString v}
      '')
      config.home.sessionVariables
    )}
    ${config.home.sessionVariablesExtra}
    exec "$@"
  '';
}
