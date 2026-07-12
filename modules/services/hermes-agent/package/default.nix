{
  config,
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  inherit (config.services.hermes-agent) stateDir workingDirectory;
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

      # hermesForDesktop: hermesAgent passed to desktop.nix (becomes HERMES_DESKTOP_HERMES).
      # Desktop resolver step 4 does `verifyHermesCli` which runs `... --version`.
      # Upstream CLI only supports `hermes version` subcommand for the version string,
      # so map top-level --version to the subcommand so the probe exits 0.
      hermesForDesktop = pkgs.writeShellScriptBin "hermes" ''
        if [ "$1" = "--version" ]; then
          exec ${pkgs.lib.getExe hermesPkg} version
        fi
        exec ${pkgs.lib.getExe hermesPkg} "$@"
      '';

      hermesDesktopRaw = pkgs.callPackage "${hermesPkgSrc}/nix/desktop.nix" {
        hermesAgent = hermesForDesktop;
        hermesNpmLib = hermesPkg.passthru.hermesNpmLib;
        inherit (pkgs) electron;
      };

      # Upstream nix/desktop.nix writes placeholder stamp commit="nix" (len<7).
      # main.cjs:loadInstallStamp requires schemaVersion=1 and commit >=7 chars.
      # Rewrite with real flake rev so packaged desktop's stamp is accepted
      # and resolver does not fall through looking for SOURCE_REPO_ROOT.
      rev = inputs.hermes-agent.rev or "0000000000000000000000000000000000000000";
      hermesDesktop = pkgs.runCommandLocal "${hermesDesktopRaw.name}-stamped" { } ''
        cp -r ${hermesDesktopRaw} "$out"
        chmod -R u+w "$out"
        printf '{"schemaVersion":1,"commit":"%s","branch":null,"dirty":false,"source":"nix"}\n' \
          ${pkgs.lib.escapeShellArg rev} \
          > "$out/share/hermes-desktop/install-stamp.json"
      '';

      hermesDesktopEntry = pkgs.makeDesktopItem {
        name = "hermes-agent";
        desktopName = "Hermes Agent";
        comment = "Desktop app for Hermes Agent";
        exec = "hermes-desktop";
        icon = "hermes-agent";
        terminal = false;
        categories = [
          "Development"
          "Utility"
        ];
        startupNotify = true;
      };
      hermesDesktopIcon = pkgs.runCommandLocal "hermes-agent-desktop-icon" { } ''
        mkdir -p "$out/share/icons/hicolor/512x512/apps"
        cp "${hermesPkgSrc}/apps/desktop/assets/icon.png" "$out/share/icons/hicolor/512x512/apps/hermes-agent.png"
      '';
    in
    pkgs.symlinkJoin {
      inherit (hermesPkg) name;
      paths = [
        hermesPkg
        hermesDesktop
        hermesDesktopEntry
        hermesDesktopIcon
      ];
      postBuild = ''
        rm "$out/bin/hermes-desktop"
        cat > "$out/bin/hermes-desktop" <<EOF
        #!${pkgs.runtimeShell}
        export HERMES_HOME=${pkgs.lib.escapeShellArg "${stateDir}/.hermes"}
        exec "${hermesDesktop}/bin/hermes-desktop" "\$@"
        EOF
        chmod +x "$out/bin/hermes-desktop"

        rm "$out/bin/hermes"
        cat > "$out/bin/hermes" <<EOF
        #!${pkgs.runtimeShell}
        if [ "\$1" = "desktop" ] || [ "\$1" = "gui" ]; then
          shift
          exec "$out/bin/hermes-desktop" "\$@"
        fi
        if [ "\$1" = "--version" ]; then
          exec ${pkgs.lib.getExe hermesPkg} version
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
      inherit (hermesPkg) meta;
    };
in
{
  config.services.hermes-agent.package = makeHermesPackage { };
}
