{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.programs.herdr;
  tomlFormat = pkgs.formats.toml { };
  defaultPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  builtInThemes = [
    "catppuccin"
    "catppuccin-latte"
    "terminal"
    "tokyo-night"
    "tokyo-night-day"
    "dracula"
    "nord"
    "gruvbox"
    "gruvbox-light"
    "one-dark"
    "one-light"
    "solarized"
    "solarized-light"
    "kanagawa"
    "kanagawa-lotus"
    "rose-pine"
    "rose-pine-dawn"
    "vesper"
  ];
  opencodePlugin = ''
    // installed by herdr
    // managed by Nix; update this file with the pinned herdr input.
    // HERDR_INTEGRATION_ID=opencode
    // HERDR_INTEGRATION_VERSION=3

    import net from "node:net";

    const SOURCE = "herdr:opencode";
    let reportSeq = Date.now() * 1000;

    function nextReportSeq() {
      reportSeq += 1;
      return reportSeq;
    }

    function sessionIDFromProperties(properties) {
      return typeof properties?.sessionID === "string" && properties.sessionID
        ? properties.sessionID
        : undefined;
    }

    function reportState(action, sessionID) {
      const paneId = process.env.HERDR_PANE_ID;
      const socketPath = process.env.HERDR_SOCKET_PATH;

      if (!paneId || !socketPath) {
        return Promise.resolve();
      }

      const requestId = `''${SOURCE}:''${Date.now()}:''${Math.floor(Math.random() * 1_000_000)
        .toString()
        .padStart(6, "0")}`;
      const params =
        action === "release"
          ? {
              pane_id: paneId,
              source: SOURCE,
              agent: "opencode",
              seq: nextReportSeq(),
            }
          : {
              pane_id: paneId,
              source: SOURCE,
              agent: "opencode",
              state: action,
              seq: nextReportSeq(),
              ...(sessionID ? { agent_session_id: sessionID } : {}),
            };
      const request = {
        id: requestId,
        method: action === "release" ? "pane.release_agent" : "pane.report_agent",
        params,
      };

      return new Promise((resolve) => {
        const client = net.createConnection(socketPath, () => {
          client.write(`''${JSON.stringify(request)}\n`);
        });

        const finish = () => {
          client.destroy();
          resolve();
        };

        client.setTimeout(500, finish);
        client.on("data", finish);
        client.on("error", finish);
        client.on("end", finish);
        client.on("close", resolve);
      });
    }

    export const HerdrAgentStatePlugin = async () => {
      if (
        process.env.HERDR_ENV !== "1" ||
        !process.env.HERDR_SOCKET_PATH ||
        !process.env.HERDR_PANE_ID
      ) {
        return {};
      }

      return {
        dispose: async () => {
          await reportState("release");
        },
        event: async ({ event }) => {
          const type = event?.type;
          const properties = event?.properties ?? {};
          const sessionID = sessionIDFromProperties(properties);

          switch (type) {
            case "permission.asked":
            case "question.asked":
              await reportState("blocked", sessionID);
              break;
            case "permission.replied": {
              const reply = properties.reply ?? properties.response;
              if (reply === "reject") {
                await reportState("idle", sessionID);
              } else if (reply === "once" || reply === "always") {
                await reportState("working", sessionID);
              }
              break;
            }
            case "question.replied":
              await reportState("working", sessionID);
              break;
            case "question.rejected":
              await reportState("idle", sessionID);
              break;
            case "session.created":
            case "session.updated":
              break;
            case "session.status": {
              const status =
                typeof properties.status === "string"
                  ? properties.status
                  : properties.status?.type;
              if (status === "busy" || status === "retry") {
                await reportState("working", sessionID);
              } else if (status === "idle") {
                await reportState("idle", sessionID);
              }
              break;
            }
            case "session.idle":
              await reportState("idle", sessionID);
              break;
            default:
              break;
          }
        },
      };
    };
  '';
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr terminal multiplexer";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "The Herdr package to install.";
    };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = "Settings written to ~/.config/herdr/config.toml.";
    };

    onboarding = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Whether to show Herdr onboarding on startup.";
    };

    theme = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum builtInThemes);
      default = null;
      description = "Built-in Herdr theme name.";
    };

    worktreeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Directory Herdr uses for Git worktree checkouts.";
    };

    toastDelivery = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "off"
          "herdr"
          "terminal"
          "system"
        ]
      );
      default = null;
      description = "How Herdr should deliver notifications.";
    };

    showAgentLabelsOnPaneBorders = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Show detected agent labels on pane borders.";
    };

    resumeAgentsOnRestore = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Resume supported agent sessions after a Herdr server restart.";
    };

    enableSound = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable Herdr sound notifications.";
    };

    enableOpencodeIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Herdr's OpenCode integration plugin.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];
        xdg.configFile."herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" (
          lib.recursiveUpdate (
            lib.optionalAttrs (cfg.onboarding != null) {
              onboarding = cfg.onboarding;
            }
            // lib.optionalAttrs (cfg.theme != null) {
              theme.name = cfg.theme;
            }
            // lib.optionalAttrs (cfg.worktreeDirectory != null) {
              worktrees.directory = cfg.worktreeDirectory;
            }
            // lib.optionalAttrs (cfg.toastDelivery != null) {
              ui.toast.delivery = cfg.toastDelivery;
            }
            // lib.optionalAttrs (cfg.showAgentLabelsOnPaneBorders != null) {
              ui.show_agent_labels_on_pane_borders = cfg.showAgentLabelsOnPaneBorders;
            }
            // lib.optionalAttrs (cfg.resumeAgentsOnRestore != null) {
              session.resume_agents_on_restore = cfg.resumeAgentsOnRestore;
            }
            // lib.optionalAttrs (cfg.enableSound != null) {
              ui.sound.enabled = cfg.enableSound;
            }
          ) cfg.settings
        );
      }
      (lib.mkIf cfg.enableOpencodeIntegration {
        home.file.".config/opencode/plugins/herdr-agent-state.js".text = opencodePlugin;
      })
    ]
  );
}
