# Repository-wide checks; individual checks can also be built by name.
# Package and host outputs are evaluated by `nix flake check`, not built.
{ inputs, ... }:
let
  inherit (inputs) self;
  pkgs = import ./_pkgs.nix { inherit inputs; };
  lint =
    name: tools: command:
    pkgs.runCommand "check-${name}" { nativeBuildInputs = tools; } ''
      cd ${self}
      ${command}
      touch $out
    '';
in
{
  flake.checks.x86_64-linux = {
    formatting = lint "formatting" [ pkgs.nixfmt pkgs.findutils ] ''
      find . -name '*.nix' -type f -print0 | xargs -0 nixfmt --check
    '';
    statix = lint "statix" [ pkgs.statix ] "statix check --config statix.toml .";
    deadnix = lint "deadnix" [
      pkgs.deadnix
    ] "deadnix --fail --no-lambda-arg --no-lambda-pattern-names .";
    imports = lint "imports" [ pkgs.check-imports ] "check-imports .";
  };
}
