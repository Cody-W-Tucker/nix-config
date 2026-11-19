{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (config.services.hermes-agent.settings.skills) disabled;

  # Skill directory names in every source a disabled entry can refer to.
  dirNames =
    path: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
  skillNames = root: lib.concatMap (category: dirNames (root + "/${category}")) (dirNames root);
  knownNames = lib.concatMap skillNames [
    inputs.cognitive-assistant.lib.artifacts.skills.categorized
    (inputs.hermes-agent + "/skills")
    (inputs.hermes-agent + "/optional-skills")
  ];
  stale = lib.subtractLists knownNames disabled;
in
{
  # Hermes hides these skills everywhere: index, slash commands, cron.
  services.hermes-agent.settings.skills.disabled = [
    # Cognitive Assistant skills that do not fit Hermes.
    "relational-orientation"
    "project-dashboard"

    # Hermes bundled and optional skills. .no-bundled-skills already keeps the
    # catalog from syncing; this also hides any the agent installs.
    "apple-notes"
    "apple-reminders"
    "findmy"
    "imessage"
    "claude-code"
    "codex"
    "ascii-video"
    "baoyu-infographic"
    "design-md"
    "manim-video"
    "popular-web-designs"
    "songwriting-and-ai-music"
    "sdlc-review"
    "himalaya"
    "gif-search"
    "songsee"
    "box"
    "google-workspace" # replaced by the gws-* skills
    "product-price-monitor"
    "arxiv"
    "competitor-news-monitor"
    "rss-feeds"
    "xurl"
    "node-inspect-debugger"
    "python-debugpy"
  ];

  warnings = lib.optional (stale != [ ]) ''
    hermes-agent/skills: these disabled skills match no skill in any source and can be removed:
    ${lib.concatStringsSep ", " stale}
  '';
}
