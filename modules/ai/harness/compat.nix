{
  den.aspects.harness.homeManager =
    {
      config,
      host,
      inputs,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      has = program: option: options.programs.${program} ? ${option};
      mutable = program: lib.optionalAttrs (has program "mutableSettings") { mutableSettings = true; };
      hasConfigMerger = lib.hm.generators ? mkImpureConfigMerger;
      hmStableHasPi = builtins.pathExists "${inputs.home-manager-stable}/modules/programs/pi-coding-agent.nix";
      pi = config.programs.pi-coding-agent;
      inherit (config.codyos.harness) claudePlugins;
    in
    {
      imports = lib.optional (
        host.channel == "stable" && !hmStableHasPi
      ) "${inputs.home-manager}/modules/programs/pi-coding-agent.nix";

      options.codyos.harness.claudePlugins = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.package lib.types.path);
        default = { };
        description = "Claude Code plugins by name, passed as a list where Home Manager only accepts one.";
      };

      config = lib.mkMerge [
        {
          programs = {
            codex = mutable "codex";
            claude-code = mutable "claude-code" // {
              plugins =
                if builtins.isList options.programs.claude-code.plugins.default then
                  lib.attrValues claudePlugins
                else
                  claudePlugins;
            };
            opencode =
              mutable "opencode"
              // lib.optionalAttrs (has "opencode" "cli") {
                tui = lib.mkForce { };
                cli.theme = {
                  name = "stylix";
                  mode = "system";
                };
              };
          };

          codyos.workarounds.harness-stable-home-manager = {
            reason = "The NAS's stable Home Manager lacks mutableSettings, programs.opencode.cli, named Claude plugins, the Pi module and mkImpureConfigMerger; compat.nix bridges each where it is missing.";
            upstream = "https://github.com/nix-community/home-manager/pull/9654";
            reviewBy = "2027-06-30";
            obsolete = hmStableHasPi && inputs.home-manager-stable.lib.hm.generators ? mkImpureConfigMerger;
          };
        }

        (lib.mkIf (!hasConfigMerger) {
          programs.pi-coding-agent.mutableSettings = lib.mkForce false;
          home.file."${pi.configDir}/settings.json".enable = lib.mkForce false;
          home.activation.piSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
            (import "${inputs.home-manager}/modules/lib/generators.nix" { inherit lib; }).mkImpureConfigMerger {
              inherit pkgs;
              format = "json";
              empty = "{}";
              mode = "600";
              path = "${pi.configDir}/settings.json";
              staticSettings = (pkgs.formats.json { }).generate "pi-settings.json" pi.settings;
              jqOperation = "$dynamic * $static";
            }
          );
        })
      ];
    };
}
