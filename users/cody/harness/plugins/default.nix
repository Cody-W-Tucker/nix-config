{
  config,
  lib,
  options,
  ...
}:

let
  plugins = config.codyos.harness.plugins;

  pluginModule = lib.types.submodule {
    options = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Packages installed for this plugin.";
      };

      context = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shared context added to OpenCode and Claude Code.";
      };

      opencode = {
        file = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Single-file OpenCode plugin linked into ~/.config/opencode/plugins/<name>.ts.";
        };

        settings = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.str lib.types.attrs);
          default = null;
          description = "Entry added to programs.opencode.settings.plugins.";
        };
      };

      claudeCode = {
        plugin = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.package lib.types.path);
          default = null;
          description = "Claude Code plugin directory or package registered in programs.claude-code.plugins.";
        };

        hooks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
          default = { };
          description = "Hook entries merged into programs.claude-code.settings.hooks.";
        };
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
    ./hindsight
    ./langfuse
    ./rtk
    ./tokeneconomizer
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
      # home-manager release-26.05 only accepts a list; unstable prefers named
      # plugins and warns on the list form.
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
