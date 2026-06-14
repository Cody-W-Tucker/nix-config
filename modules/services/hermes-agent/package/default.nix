{
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hermesPkgSrc = pkgs.applyPatches {
    name = "hermes-agent-src";
    src = inputs.hermes-agent;
    patches = [
      ./patches/hermes-home-group-access.patch
      ./patches/auth-store-group-access.patch
    ];
  };
  makeHermesPackage =
    {
      extraPythonPackages ? [ ],
      extraDependencyGroups ? [ ],
    }:
    let
      hermesPkg = pkgs.callPackage "${hermesPkgSrc}/nix/hermes-agent.nix" {
        inherit (inputs.hermes-agent.inputs) uv2nix pyproject-nix pyproject-build-systems;
        npm-lockfile-fix = inputs.hermes-agent.inputs.npm-lockfile-fix.packages.${system}.default;
        rev = inputs.hermes-agent.rev or null;
        inherit extraPythonPackages extraDependencyGroups;
      };
      hermesDesktop = pkgs.callPackage "${hermesPkgSrc}/nix/desktop.nix" {
        hermesAgent = hermesPkg;
        hermesNpmLib = hermesPkg.passthru.hermesNpmLib;
        electron = pkgs.electron;
      };
    in
    pkgs.symlinkJoin {
      name = hermesPkg.name;
      paths = [
        hermesPkg
        hermesDesktop
      ];
      postBuild = ''
        rm "$out/bin/hermes"
        cat > "$out/bin/hermes" <<EOF
        #!${pkgs.runtimeShell}
        if [ "\$1" = "desktop" ] || [ "\$1" = "gui" ]; then
          shift
          exec "$out/bin/hermes-desktop" "\$@"
        fi

        exec "${hermesPkg}/bin/hermes" "\$@"
        EOF
        chmod +x "$out/bin/hermes"
      '';
      passthru = (hermesPkg.passthru or { }) // {
        inherit hermesDesktop;
        override =
          args:
          makeHermesPackage (
            {
              inherit extraPythonPackages extraDependencyGroups;
            }
            // args
          );
      };
      meta = hermesPkg.meta;
    };
in
{
  config.services.hermes-agent.package = makeHermesPackage { };
}
