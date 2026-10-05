# Invariant guard for the explicit default exclusion catalog.
# Every exclusion must be backed by Nix source/evaluated evidence
# (CA categorized, GWS upstream, knowledge entries), never runtime dirs,
# and must be absent from every filtered default pack.
{
  config,
  inputs,
  lib,
  defaultExcludedSkillPaths,
  defaultRetainedGwsSkillNames,
  allCognitiveAssistantRelPaths,
  filteredCognitiveAssistantRelPaths,
  allGwsSkillNames,
  filteredGwsSkillNames,
  allKnowledgeRelPaths,
  filteredKnowledgeRelPaths,
  ...
}:
let
  gwsSourceRels = map (name: "tools/${name}") allGwsSkillNames;
  gwsFilteredRels = map (name: "tools/${name}") filteredGwsSkillNames;
  # Nix-only artifact-source ownership for tools/gws-chat-send:
  # GWS upstream (inputs.googleworkspace-cli/skills/gws-chat-send/SKILL.md),
  # proved via store path existence, not via the 12-skill package catalog
  # (defaultRetainedGwsSkillNames) and never via runtime dirs.
  gwsChatSendSkillFile = inputs.googleworkspace-cli + "/skills/gws-chat-send/SKILL.md";
  gwsChatSendProven = builtins.pathExists gwsChatSendSkillFile;
  extraGwsSourceRels = lib.optionals gwsChatSendProven [ "tools/gws-chat-send" ];
  # Hermes upstream bundled plus optional skills as Nix artifact sources.
  # Every non-CA/non-GWS/non-knowledge exclusion (apple/*, creative/*, ...) is
  # backed by these store paths, never by runtime dirs.
  hermesSkillsRoot = inputs.hermes-agent + "/skills";
  hermesOptionalRoot = inputs.hermes-agent + "/optional-skills";
  hermesCategoryNames =
    root: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
  hermesSkillsInCategory =
    root: category:
    lib.attrNames (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir (root + "/${category}"))
    );
  hermesRelPathsForRoot =
    root:
    lib.concatMap (
      category: map (skill: "${category}/${skill}") (hermesSkillsInCategory root category)
    ) (hermesCategoryNames root);
  allHermesRelPaths = hermesRelPathsForRoot hermesSkillsRoot;
  allHermesOptionalRelPaths = hermesRelPathsForRoot hermesOptionalRoot;
  sourceRels =
    allCognitiveAssistantRelPaths
    ++ gwsSourceRels
    ++ allKnowledgeRelPaths
    ++ extraGwsSourceRels
    ++ allHermesRelPaths
    ++ allHermesOptionalRelPaths;
  defaultRels = filteredCognitiveAssistantRelPaths ++ gwsFilteredRels ++ filteredKnowledgeRelPaths;

  missingSources = lib.filter (rel: !lib.elem rel sourceRels) defaultExcludedSkillPaths;

  reseeded = lib.filter (rel: lib.elem rel defaultRels) defaultExcludedSkillPaths;

  packNames = map (pack: pack.name) config.codyos.hermes-agent.skills.skillPacks;
in
{
  config.assertions = [
    {
      assertion =
        defaultExcludedSkillPaths == [
          "apple/apple-notes"
          "apple/apple-reminders"
          "apple/findmy"
          "apple/imessage"
          "autonomous-ai-agents/claude-code"
          "autonomous-ai-agents/codex"
          "creative/ascii-video"
          "creative/baoyu-infographic"
          "creative/design-md"
          "creative/humanizer"
          "creative/manim-video"
          "creative/popular-web-designs"
          "creative/songwriting-and-ai-music"
          "devops/sdlc-review"
          "email/himalaya"
          "existential/relational-orientation"
          "media/gif-search"
          "media/songsee"
          "operational/project-dashboard"
          "productivity/airtable"
          "productivity/box"
          "productivity/google-workspace"
          "productivity/notion"
          "productivity/powerpoint"
          "productivity/product-price-monitor"
          "productivity/xlsx"
          "research/arxiv"
          "research/competitor-news-monitor"
          "research/rss-feeds"
          "social-media/xurl"
          "software-development/node-inspect-debugger"
          "software-development/python-debugpy"
          "tools/gws-admin-reports"
          "tools/gws-chat"
          "tools/gws-chat-send"
          "tools/gws-classroom"
          "tools/gws-docs"
          "tools/gws-docs-write"
          "tools/gws-drive"
          "tools/gws-drive-upload"
          "tools/gws-events"
          "tools/gws-events-renew"
          "tools/gws-events-subscribe"
          "tools/gws-forms"
          "tools/gws-gmail-forward"
          "tools/gws-gmail-reply-all"
          "tools/gws-gmail-watch"
          "tools/gws-keep"
          "tools/gws-meet"
          "tools/gws-modelarmor"
          "tools/gws-modelarmor-create-template"
          "tools/gws-modelarmor-sanitize-prompt"
          "tools/gws-modelarmor-sanitize-response"
          "tools/gws-script"
          "tools/gws-script-push"
          "tools/gws-sheets"
          "tools/gws-sheets-append"
          "tools/gws-sheets-read"
          "tools/gws-slides"
          "tools/gws-workflow"
          "tools/gws-workflow-email-to-task"
          "tools/gws-workflow-file-announce"
          "tools/gws-workflow-meeting-prep"
          "tools/gws-workflow-standup-report"
          "tools/gws-workflow-weekly-digest"
          "tools/obsidian-bases"
          "tools/obsidian-cli"
        ];
      message = "hermes-agent/skills: defaultExcludedSkillPaths must stay exactly the 66-path exclusion catalog (change deliberately with review).";
    }
    {
      assertion =
        defaultRetainedGwsSkillNames == [
          "gws-calendar"
          "gws-gmail-triage"
          "gws-tasks"
          "gws-calendar-agenda"
          "gws-calendar-insert"
          "gws-gmail-send"
          "gws-gmail-read"
          "gws-gmail-reply"
          "gws-people"
          "gws-shared"
          "gws-nas-oauth"
          "gws-gmail"
        ];
      message = "hermes-agent/skills: defaultRetainedGwsSkillNames must stay exactly the 12-skill GWS retain set.";
    }
    {
      assertion = filteredGwsSkillNames == defaultRetainedGwsSkillNames;
      message = "hermes-agent/skills: google-workspace-tools pack must contain exactly the retained GWS catalog.";
    }
    {
      assertion =
        filteredKnowledgeRelPaths == [
          "tools/obsidian-markdown"
          "tools/qmd"
          "research/research-state"
        ];
      message = "hermes-agent/skills: knowledge-tools must retain only obsidian-markdown, qmd, and research-state after exclusions.";
    }
    {
      assertion = lib.elem "crm-tools" packNames;
      message = "hermes-agent/skills: crm-tools pack must stay (CRM stays).";
    }
    {
      assertion = missingSources == [ ];
      message = "hermes-agent/skills: every default exclusion must exist in CA/GWS/knowledge Nix source (evaluated evidence, not runtime dirs).";
    }
    {
      assertion = gwsChatSendProven;
      message = "hermes-agent/skills: tools/gws-chat-send must exist in GWS upstream Nix source (googleworkspace-cli/skills/gws-chat-send/SKILL.md), not package catalog or runtime dirs.";
    }
    {
      assertion = reseeded == [ ];
      message = "hermes-agent/skills: every default exclusion must be absent from the filtered default packs (CA filtered, GWS retained, knowledge filtered).";
    }
    {
      assertion =
        builtins.length filteredCognitiveAssistantRelPaths == builtins.length allCognitiveAssistantRelPaths
        - builtins.length (lib.intersectLists allCognitiveAssistantRelPaths defaultExcludedSkillPaths);
      message = "hermes-agent/skills: filtered CA pack must retain all non-excluded CA skills.";
    }
  ];
}
