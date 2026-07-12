{
  config,
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  # Build with Hermes' own locked nixpkgs. The desktop's Electron ABI and
  # node-pty headers must come from the same package set as upstream Hermes.
  hermesPkgs = inputs.hermes-agent.inputs.nixpkgs.legacyPackages.${system};

  # Apply the minimal desktop compatibility patch. The desktop mints and gives
  # its local headless `hermes serve` child this token, so it must use that
  # token directly rather than requesting a web-dashboard document. Patch only
  # the desktop source; the upstream CLI package and NixOS module stay intact.
  patchedSrc = hermesPkgs.applyPatches {
    name = "hermes-agent-desktop-patched";
    src = inputs.hermes-agent;
    patches = [
      ./patches/desktop-local-token-bypass.patch
    ];
  };

  # hermesNpmLib from the *patched* tree so its `src = ../.;` resolves to the
  # patched tree (the buildNpmPackage will see our edited .ts files).
  hermesNpmLib = hermesPkgs.callPackage "${patchedSrc}/nix/lib.nix" {
    npm-lockfile-fix = inputs.hermes-agent.inputs.npm-lockfile-fix.packages.${system}.default;
    nodejs = hermesPkgs.nodejs_22;
  };

  # Use upstream's CLI package (preserves isolated hermes nixpkgs + service
  # module wiring + managed HERMES_HOME). Desktop only needs the exe path.
  hermesCli = inputs.hermes-agent.packages.${system}.default;

  # Build the upstream desktop derivation from the patched tree.
  originalHermesDesktop = hermesPkgs.callPackage "${patchedSrc}/nix/desktop.nix" {
    inherit hermesNpmLib;
    hermesAgent = hermesCli;
    electron = hermesPkgs.electron;
  };

  # Wrap so that desktop (launched via xdg entry, "hermes desktop", menus, etc.)
  # receives the same API_SERVER_KEY (and other hermes env) that the service
  # gets. The .env is written by activation from environment + sops template.
  # This ensures desktop process.env has the key for any internal API calls
  # (Bearer auth to local API server on 8642), avoiding 401s. Use symlinkJoin
  # so icons/share from original are preserved while bin/hermes-desktop is
  # overridden by the launcher.
  hermesDesktop = pkgs.symlinkJoin {
    name = "hermes-agent-desktop-wrapped";
    paths = [
      (pkgs.writeShellScriptBin "hermes-desktop" ''
        set -a
        . "${config.services.hermes-agent.stateDir}/.hermes/.env" 2>/dev/null || { echo "hermes-desktop: failed to source the hermes .env (missing/unreadable or cannot be sourced)" >&2; exit 1; }
        set +a
        exec ${originalHermesDesktop}/bin/hermes-desktop "$@"
      '')
      originalHermesDesktop
    ];
  };

in
{
  # The upstream service module exports the managed HERMES_HOME globally, so
  # both terminal and XDG launches of this wrapped binary share its state.
  # Do not override services.hermes-agent.package: its CLI and module retain
  # ownership of the daemon and state lifecycle.
  config._module.args.hermesDesktop = hermesDesktop;
}
