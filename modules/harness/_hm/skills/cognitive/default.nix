{
  inputs,
  lib,
  ...
}:

let
  skills = inputs.cognitive-assistant.lib.artifacts.skills.files;
in
{
  # The upstream artifacts tag every skill as OpenCode-only; they are shared
  # with every harness here, so drop that frontmatter line.
  codyos.harness.skills = lib.mapAttrs (
    _: builtins.replaceStrings [ "compatibility: opencode\n" ] [ "" ]
  ) skills;
}
