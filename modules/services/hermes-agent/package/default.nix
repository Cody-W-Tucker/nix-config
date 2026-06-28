{
  config,
  hermesComputerUsePackageEnv,
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
      ./patches/cua-backend-null-tolerant.patch
    ];
    postPatch = ''
      old_titlebar_overlay=$(cat <<'EOF'
      if (!IS_WINDOWS && IS_WSL) {
      EOF
      )

      new_titlebar_overlay=$(cat <<'EOF'
      if (process.platform === 'linux') {
      EOF
      )

            substituteInPlace apps/desktop/electron/main.cjs \
              --replace-fail "$old_titlebar_overlay" "$new_titlebar_overlay"
    '';
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
        inherit (pkgs) electron;
      };
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
        ${hermesComputerUsePackageEnv}
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

        ${hermesComputerUsePackageEnv}
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
  imports = [
    ./cua-driver.nix
    ./computer-use.nix
  ];

  config.services.hermes-agent.package = makeHermesPackage { };
}
