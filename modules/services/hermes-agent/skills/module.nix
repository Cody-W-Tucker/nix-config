{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.codyos.hermes-agent.skills;
  inherit (config.services.hermes-agent) hermesHome;
  packsIn = mode: lib.filter (pack: pack.mode == mode) cfg.skillPacks;
in
{
  options.codyos.hermes-agent.skills.skillPacks = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable name for this Hermes skill pack.";
          };

          root = lib.mkOption {
            type = lib.types.path;
            description = "Root directory containing category/skill directories.";
          };

          mode = lib.mkOption {
            type = lib.types.enum [
              "mutable"
              "managed"
            ];
            default = "mutable";
            description = ''
              managed: Hermes reads the pack from the Nix store through
              skills.external_dirs. Nix is the source of truth, and the curator
              does not edit external skills.

              mutable: each skill is copied into the local skills tree once, so
              the agent and curator can patch it. Local edits survive
              activation; upstream changes do not reach a skill already copied.
            '';
          };
        };
      }
    );
    default = [ ];
    description = "Declarative Hermes skill packs.";
  };

  config = {
    services.hermes-agent.settings.skills.external_dirs = map (pack: "${pack.root}") (
      packsIn "managed"
    );

    home.activation.hermesAgentSkills = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
      mkdir -p "${hermesHome}/skills"
      ${lib.concatMapStrings (pack: ''
        ${pkgs.coreutils}/bin/cp -rL --update=none --no-preserve=mode,ownership \
          "${pack.root}/." "${hermesHome}/skills/"
      '') (packsIn "mutable")}
      # Same marker `hermes skills opt-out` writes: never seed the bundled catalog.
      touch "${hermesHome}/.no-bundled-skills"
    '';
  };
}
