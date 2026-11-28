{
  den.aspects.harness.homeManager =
    {
      config,
      host,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      stableLacksPi =
        host.channel == "stable"
        && !(builtins.pathExists "${inputs.home-manager-stable}/modules/programs/pi-coding-agent.nix");
      hasConfigMerger = lib.hm.generators ? mkImpureConfigMerger;
      piShell.shellPath = config.programs.opencode.settings.shell;
    in
    {
      imports = lib.optional stableLacksPi "${inputs.home-manager}/modules/programs/pi-coding-agent.nix";

      programs.pi-coding-agent = {
        enable = true;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
      }
      // lib.optionalAttrs hasConfigMerger {
        mutableSettings = true;
        settings = piShell;
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

      home.file."${config.programs.pi-coding-agent.configDir}/mcp.json".text = builtins.toJSON {
        mcpServers = lib.mapAttrs (
          _: server: lib.filterAttrs (_: value: value != null && value != [ ] && value != { }) server
        ) config.programs.mcp.servers;
      };

      codyos.workarounds.pi-config-merger = {
        reason = "Stable Home Manager lacks mkImpureConfigMerger, so piShellSettings merges Pi's settings.json during activation where it is missing.";
        upstream = "https://github.com/nix-community/home-manager/pull/9654";
        reviewBy = "2027-06-30";
        obsolete = inputs.home-manager-stable.lib.hm.generators ? mkImpureConfigMerger;
      };
    };
}
