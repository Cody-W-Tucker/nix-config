{
  lib,
  ...
}:

{
  options.codyos.hermes-agent.skills = {
    skillPacks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable name for this Hermes skill pack.";
            };

            root = lib.mkOption {
              type = lib.types.path;
              description = "Root directory containing Hermes-style skill directories.";
            };

            mode = lib.mkOption {
              type = lib.types.enum [
                "mutable"
                "managed"
              ];
              default = "mutable";
              description = ''
                How the pack is copied into Hermes' local skill tree.

                mutable: copy only when the local skill is absent or malformed; local agent edits survive.
                managed: replace the local skill from the pack on each activation; Nix is source of truth.
              '';
            };

          };
        }
      );
      default = [ ];
      description = "Declarative Hermes skill packs to seed into the mutable local skills tree.";
    };

    seedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Legacy mutable skill directories to seed into Hermes' local skills tree.";
    };

    userPatternSkillList = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Rendered list of Cognitive Assistant user-pattern skills for the Hermes AGENTS document.";
    };
  };
}
