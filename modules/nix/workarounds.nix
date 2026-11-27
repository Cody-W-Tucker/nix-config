{ den, inputs, ... }:
let
  module =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      inherit (lib) mkOption types;

      today = builtins.substring 0 8 inputs.self.lastModifiedDate;
      dateKey = lib.replaceStrings [ "-" ] [ "" ];

      repoPath =
        file:
        let
          inRepo = builtins.match "/nix/store/[^/]*-source/(.*)" file;
        in
        if inRepo == null then file else lib.head inRepo;

      locations = lib.foldl' (
        acc: def:
        acc
        // lib.optionalAttrs (lib.isAttrs def.value && !(def.value ? _type)) (
          lib.genAttrs (lib.attrNames def.value) (_: repoPath def.file)
        )
      ) { } options.codyos.workarounds.definitionsWithLocations;

      describe =
        name: w:
        "Workaround `${name}` in ${locations.${name} or "an unknown file"}: ${w.reason} (${w.upstream})";

      workaroundType = types.submodule {
        options = {
          reason = mkOption {
            type = types.str;
            description = "What is broken upstream and what the workaround changes.";
          };
          upstream = mkOption {
            type = types.str;
            description = "Issue, pull request or commit URL that tracks the upstream fix.";
          };
          reviewBy = mkOption {
            type = types.strMatching "[0-9]{4}-[0-9]{2}-[0-9]{2}";
            description = "Date after which every build warns until the workaround is removed or re-reviewed.";
          };
          obsolete = mkOption {
            type = types.bool;
            default = false;
            description = "Consumer-scoped predicate that is true once the workaround is no longer needed.";
          };
        };
      };
    in
    {
      options.codyos.workarounds = mkOption {
        type = types.attrsOf workaroundType;
        default = { };
        description = "Temporary workarounds. Each one warns when it is obsolete or past its review date.";
      };

      config.warnings = lib.concatLists (
        lib.mapAttrsToList (
          name: w:
          if w.obsolete then
            [ "${describe name w} is obsolete. Remove it and its entry." ]
          else
            lib.optional (today >= dateKey w.reviewBy)
              "${describe name w} passed its review date ${w.reviewBy}. Check upstream, then remove it or set a new reviewBy."
        ) config.codyos.workarounds
      );
    };
in
{
  den.aspects.workarounds = {
    nixos = module;
    provides.to-users.homeManager = module;
  };

  den.default.includes = [ den.aspects.workarounds ];
}
