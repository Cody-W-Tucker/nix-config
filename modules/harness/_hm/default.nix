{ localAi }:
{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piLangfuseDir = "${config.home.homeDirectory}/.pi/agent/langfuse-plugin";
  piShell = {
    shellPath = import ./runtime.nix { inherit inputs lib pkgs; };
  };
  hasConfigMerger = lib.hm.generators ? mkImpureConfigMerger;
in

{
  imports = [
    ./claude-code
    ./codex
    ./opencode
    ./context.nix
    ./inbox
    (import ./mcp.nix { inherit localAi; })
    (import ./plugins { inherit localAi; })
    ./skills
    ./coding-tools.nix
  ]
  ++
    lib.optionals
      (
        localAi
        && !(builtins.pathExists "${inputs.home-manager-stable}/modules/programs/pi-coding-agent.nix")
      )
      [
        "${inputs.home-manager}/modules/programs/pi-coding-agent.nix"
      ];

  home.packages = [
    llmPkgs.cursor-agent
    llmPkgs.muse-code
    llmPkgs.grok

    llmPkgs.herdr-core

    llmPkgs.tuicr

    llmPkgs.spec-kit
    llmPkgs.backlog-md
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = llmPkgs.pi;
  }
  // lib.optionalAttrs hasConfigMerger {
    mutableSettings = true;
    settings = piShell;
  };

  codyos.workarounds.pi-config-merger = {
    reason = "Stable Home Manager lacks mkImpureConfigMerger, so piShellSettings merges Pi's settings.json during activation where it is missing.";
    upstream = "https://github.com/nix-community/home-manager/pull/9654";
    reviewBy = "2027-06-30";
    obsolete = inputs.home-manager-stable.lib.hm.generators ? mkImpureConfigMerger;
  };

  home.activation.piShellSettings = lib.mkIf (!hasConfigMerger) (
    lib.hm.dag.entryAfter [ "linkGeneration" ] (
      (import "${inputs.home-manager}/modules/lib/generators.nix" { inherit lib; }).mkImpureConfigMerger {
        inherit pkgs;
        format = "json";
        empty = "{}";
        mode = "600";
        path = "${config.programs.pi-coding-agent.configDir}/settings.json";
        staticSettings = (pkgs.formats.json { }).generate "pi-shell.json" piShell;
        jqOperation = "$dynamic * $static";
      }
    )
  );

  home.file.".pi/agent/extensions/langfuse.ts".text = ''
    export { default } from "${piLangfuseDir}/node_modules/@langfuse/pi-observability-plugin/src/index.ts";
  '';
  home.activation.piLangfusePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${lib.getBin pkgs.nodejs}/bin:$PATH"
    plugin_dir="${piLangfuseDir}"
    manifest="$plugin_dir/node_modules/@langfuse/pi-observability-plugin/package.json"
    version="$(node -p "require('$manifest').version" 2>/dev/null || true)"
    if [ "$version" != "0.1.2" ]; then
      mkdir -p "$plugin_dir"
      npm install --prefix "$plugin_dir" --no-save --no-package-lock --ignore-scripts --no-audit --no-fund '@langfuse/pi-observability-plugin@0.1.2'
    fi
  '';

  xdg.configFile."deja/exclude".text = ''
    harness:pi
  '';

  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
