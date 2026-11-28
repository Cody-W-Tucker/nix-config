{ localAi }:
{
  config,
  lib,
  options,
  ...
}:
let
  inherit (config.codyos.harness) plugins;

  opt =
    type: default: description:
    lib.mkOption { inherit type default description; };

  pluginModule = lib.types.submodule {
    options = {
      packages = opt (lib.types.listOf lib.types.package) [ ] "Packages installed for this plugin.";
      context = opt lib.types.lines "" "Shared context added to OpenCode and Claude Code.";

      opencode = {
        file =
          opt (lib.types.nullOr lib.types.path) null
            "Single-file OpenCode plugin linked into ~/.config/opencode/plugins/<name>.ts.";
        settings = opt (lib.types.nullOr (
          lib.types.either lib.types.str lib.types.attrs
        )) null "Entry added to programs.opencode.settings.plugins.";
      };

      claudeCode = {
        plugin = opt (lib.types.nullOr (
          lib.types.either lib.types.package lib.types.path
        )) null "Claude Code plugin directory or package registered in programs.claude-code.plugins.";
        hooks = opt (lib.types.attrsOf (
          lib.types.listOf lib.types.attrs
        )) { } "Hook entries merged into programs.claude-code.settings.hooks.";
      };
    };
  };

  opencodeFileEntries = lib.mapAttrs' (
    name: p: lib.nameValuePair "opencode/plugins/${name}.ts" { source = p.opencode.file; }
  ) (lib.filterAttrs (_: p: p.opencode.file != null) plugins);

  opencodeSettingsEntries = lib.concatMap (
    p: lib.optional (p.opencode.settings != null) p.opencode.settings
  ) (lib.attrValues plugins);

  claudePluginAttrs = lib.mapAttrs (_: p: p.claudeCode.plugin) (
    lib.filterAttrs (_: p: p.claudeCode.plugin != null) plugins
  );

  claudeHooks = lib.foldl' (
    acc: p:
    lib.zipAttrsWith (_: lib.concatLists) [
      acc
      p.claudeCode.hooks
    ]
  ) { } (lib.attrValues plugins);

  pluginContexts = lib.concatStringsSep "\n\n" (
    lib.filter (c: c != "") (map (p: p.context) (lib.attrValues plugins))
  );
in
{
  imports = [
    (import ./hindsight { inherit localAi; })
    ./langfuse
    ./no-comments
    ./rtk
  ];

  options.codyos.harness.plugins = lib.mkOption {
    type = lib.types.attrsOf pluginModule;
    default = { };
    description = ''
      Plugins shared across OpenCode and Claude Code. Each entry can contribute
      packages, shared context, an OpenCode plugin file or settings entry, and
      a Claude Code plugin directory or hook configuration.
    '';
  };

  config = {
    home.packages = lib.concatMap (p: p.packages) (lib.attrValues plugins);

    xdg.configFile = opencodeFileEntries;

    programs.opencode = {
      settings.plugins = opencodeSettingsEntries;
      context = lib.mkIf (pluginContexts != "") pluginContexts;
    };

    programs.claude-code = {
      plugins =
        if builtins.isList options.programs.claude-code.plugins.default then
          lib.attrValues claudePluginAttrs
        else
          claudePluginAttrs;

      settings.hooks = lib.mkIf (claudeHooks != { }) claudeHooks;
      context = lib.mkIf (pluginContexts != "") pluginContexts;
    };
  };
}
