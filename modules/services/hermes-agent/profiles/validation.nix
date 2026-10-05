# Invariant guard: exactly three parked profiles with bounded MCP/toolset/skill/compression shape.
{
  config,
  lib,
  profileDefinitions,
  salesBusinessPacks,
  skillPacksByName,
  profileSettings,
  mkProfileSettings,
  ...
}:
let
  profiles = profileDefinitions;
  hermesDefaults = config.services.hermes-agent.settings;
in
{
  config.assertions = [
    {
      assertion =
        builtins.attrNames profiles == [
          "builder"
          "research"
          "tmv-sales"
        ];
      message = "hermes-agent/profiles: exactly tmv-sales, builder, research must be defined.";
    }
    {
      assertion = lib.all (name: lib.hasAttr name config.services.hermes-agent.mcpServers) (
        lib.concatMap (profile: profile.mcpAllow) (lib.attrValues profiles)
      );
      message = "hermes-agent/profiles: every mcpAllow entry must name a server from services.hermes-agent.mcpServers (mcp/default.nix).";
    }
    {
      assertion = profiles.tmv-sales.mcpAllow == [ "karakeep" ];
      message = "hermes-agent/profiles: tmv-sales mcpAllow must stay exactly [ karakeep ] (bounded sales exclusions).";
    }
    {
      assertion =
        profiles.tmv-sales.platformToolsets.cli == profiles.tmv-sales.platformToolsets.api_server;
      message = "hermes-agent/profiles: tmv-sales CLI must match its bounded API toolsets, including file/terminal only for CRM/GWS CLI work.";
    }
    {
      assertion =
        profiles.builder.mcpAllow == [
          "nixos"
          "code-review-graph"
        ];
      message = "hermes-agent/profiles: builder mcpAllow must stay exactly [ nixos code-review-graph ].";
    }
    {
      assertion = profiles.research.mcpAllow == [ "karakeep" ];
      message = "hermes-agent/profiles: research mcpAllow must stay exactly [ karakeep ] (read-only posture).";
    }
    {
      assertion =
        profiles.tmv-sales.curatedSkills == [
          "bind-to-operator"
          "read-the-active-mode"
          "relational-orientation"
          "decision-calibration"
          "decision-ready-not-impressive"
          "boundary-handoff"
          "redirect-from-analysis-to-action"
          "project-dashboard"
          "earned-candor-and-the-commitment-handoff"
          "separate-fear-from-clarity-and-ownership"
        ];
      message = "hermes-agent/profiles: tmv-sales curatedSkills pinned; change deliberately with review.";
    }
    {
      assertion =
        profiles.builder.curatedSkills == [
          "bound-before-solving"
          "diagnose-before-patching"
          "verify-before-trust"
          "failure-recovery"
          "collapse-unearned-complexity"
          "complexity-reduction"
          "scope-framing"
          "skip-the-default-scripts"
          "additive-thinking-partner"
          "system-building-as-meaning-making"
        ];
      message = "hermes-agent/profiles: builder curatedSkills pinned; change deliberately with review.";
    }
    {
      assertion =
        profiles.research.curatedSkills == [
          "bound-before-solving"
          "verify-before-trust"
          "mode-detection"
          "scope-framing"
          "complexity-reduction"
          "read-the-active-mode"
          "redirect-from-analysis-to-action"
          "avoidance-vs-misalignment-discriminator"
        ];
      message = "hermes-agent/profiles: research curatedSkills pinned; change deliberately with review.";
    }
    {
      assertion =
        salesBusinessPacks == [
          "crm-tools"
          "google-workspace-tools"
        ];
      message = "hermes-agent/profiles: sales business packs must stay exactly [ crm-tools google-workspace-tools ] (declarative CRM/GWS).";
    }
    {
      assertion =
        profiles.tmv-sales.businessPacks == salesBusinessPacks
        && profiles.builder.businessPacks == [ ]
        && profiles.research.businessPacks == [ ];
      message = "hermes-agent/profiles: only tmv-sales seeds business packs; builder/research must stay empty.";
    }
    {
      assertion = lib.all (name: lib.hasAttr name skillPacksByName) salesBusinessPacks;
      message = "hermes-agent/profiles: sales business packs must exist in codyos.hermes-agent.skills.skillPacks (skills/business/crm and google-workspace).";
    }
    {
      assertion = hermesDefaults.model.default == "gpt-5.6-terra";
      message = "hermes-agent/profiles: default model must stay gpt-5.6-terra (from services.hermes-agent.settings).";
    }
    {
      assertion = hermesDefaults.model.provider == "openai-codex";
      message = "hermes-agent/profiles: default provider must stay openai-codex (from services.hermes-agent.settings).";
    }
    {
      assertion = lib.all (
        settings:
        settings.model == {
          default = hermesDefaults.model.default;
          provider = hermesDefaults.model.provider;
        }
        && settings.fallback_model == hermesDefaults.fallback_model
        && settings.auxiliary == hermesDefaults.auxiliary
      ) (lib.attrValues profileSettings);
      message = "hermes-agent/profiles: every named config must carry the complete model/fallback/auxiliary routing from the main defaults.";
    }
    {
      assertion = lib.all (settings: settings.web == hermesDefaults.web) (lib.attrValues profileSettings);
      message = "hermes-agent/profiles: every named config must carry the root non-secret web backend settings.";
    }
    {
      assertion = (mkProfileSettings "tmv-sales" profiles.tmv-sales).compression.threshold == 0.70;
      message = "hermes-agent/profiles: tmv-sales generated compression threshold must be 0.70.";
    }
    {
      assertion =
        (mkProfileSettings "research" profiles.research).compression.threshold == 0.65
        && (mkProfileSettings "research" profiles.research).compression.micro_compact == false;
      message = "hermes-agent/profiles: research generated compression must be 0.65 with micro_compact false.";
    }
    {
      assertion = (mkProfileSettings "tmv-sales" profiles.tmv-sales).compression.micro_compact == false;
      message = "hermes-agent/profiles: named configs must retain micro_compact false.";
    }
    {
      assertion = profiles.tmv-sales.compressionThreshold == 0.70;
      message = "hermes-agent/profiles: tmv-sales compression threshold must be 0.70.";
    }
    {
      assertion = profiles.research.compressionThreshold == 0.65;
      message = "hermes-agent/profiles: research compression threshold must be 0.65.";
    }
    {
      assertion = lib.all (profile: profile.compressionThreshold <= 0.70) (lib.attrValues profiles);
      message = "hermes-agent/profiles: profile thresholds must sit at or below the main 0.70 default.";
    }
  ];
}
