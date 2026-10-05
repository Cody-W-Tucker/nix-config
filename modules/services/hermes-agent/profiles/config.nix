# Generated per-profile config (Nix-owned config.yaml, SOUL.md, profile.yaml); dynamic _config_version only.
{
  config,
  inputs,
  lib,
  pkgs,
  profileDefinitions,
  ...
}:
let
  hermesPkg = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesVenvPython = "${hermesPkg.hermesVenv}/bin/python3";
  common = import (inputs.hermes-agent + "/nix/moduleCommon.nix") { inherit lib; };
  caArtifacts = inputs.cognitive-assistant.lib.artifacts;
  soulCore = builtins.readFile caArtifacts.alignment.translationLayer;

  # Single source of truth for model routing: reuse the main Hermes defaults.
  # No credentials live in these blocks (model, fallback, auxiliary are routing-only).
  hermesDefaults = config.services.hermes-agent.settings;

  skillPacksByName = lib.listToAttrs (
    map (p: {
      name = p.name;
      value = p;
    }) config.codyos.hermes-agent.skills.skillPacks
  );

  # Nix overwrites SOUL.md every activation.
  mkSoul =
    overlay:
    pkgs.writeText "hermes-profile-soul.md" ''
      ${soulCore}

      ${overlay}
    '';

  mkProfileSettings = name: profile: {
    model = {
      default = hermesDefaults.model.default;
      provider = hermesDefaults.model.provider;
    };
    fallback_model = hermesDefaults.fallback_model;
    auxiliary = hermesDefaults.auxiliary;
    # Inherit backend selection only; credentials remain in environment files.
    web = hermesDefaults.web;
    mcp_servers = common.mcpServersToConfig (
      lib.filterAttrs (
        serverName: _: lib.elem serverName profile.mcpAllow
      ) config.services.hermes-agent.mcpServers
    );
    platform_toolsets = profile.platformToolsets;
    compression = {
      enabled = true;
      threshold = profile.compressionThreshold;
      micro_compact = false;
    };
    memory = {
      memory_enabled = true;
      provider = "holographic";
      user_profile_enabled = true;
    };
  };

  mkProfileConfig =
    name: profile:
    pkgs.runCommand "hermes-profile-${name}-config.json"
      {
        settings = builtins.toJSON (mkProfileSettings name profile);
        passAsFile = [ "settings" ];
      }
      ''
        HOME=$TMPDIR ${hermesVenvPython} - "$settingsPath" > $out <<'PY'
        import json, sys
        from hermes_cli.config_defaults import DEFAULT_CONFIG
        with open(sys.argv[1]) as f:
            settings = json.load(f)
        settings.setdefault("_config_version", DEFAULT_CONFIG["_config_version"])
        json.dump(settings, sys.stdout)
        PY
      '';

  profileConfigs = lib.mapAttrs mkProfileConfig profileDefinitions;
  profileSouls = lib.mapAttrs (_: profile: mkSoul profile.overlay) profileDefinitions;
  profileSettings = lib.mapAttrs mkProfileSettings profileDefinitions;

  profileMeta = lib.mapAttrs (
    _: profile:
    pkgs.writeText "hermes-profile-meta.yaml" (
      lib.generators.toYAML { } {
        description = profile.description;
        description_auto = false;
        display_name = profile.displayName;
      }
    )
  ) profileDefinitions;
in
{
  _module.args.mkProfileSettings = mkProfileSettings;
  _module.args.profileConfigs = profileConfigs;
  _module.args.profileSouls = profileSouls;
  _module.args.profileSettings = profileSettings;
  _module.args.profileMeta = profileMeta;
  _module.args.skillPacksByName = skillPacksByName;
}
