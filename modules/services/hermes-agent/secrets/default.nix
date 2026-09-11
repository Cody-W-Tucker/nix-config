{
  config,
  lib,
  ...
}:

let
in
{
  config = {
    # `hermes` is a single multiline secret whose plaintext is plain
    # KEY=value lines carrying the agent's env var names directly
    # (TELEGRAM_BOT_TOKEN, API_SERVER_KEY, ...). Templates render it
    # verbatim, so there is no rename step.
    sops.secrets."hermes" = { };
    sops.secrets."opencode-api-key" = { };

    # Actual Budget MCP credentials, consumed by the Actual Budget MCP
    # wrapper (npx) in ../mcp/default.nix via direct secret paths (not env
    # templates).
    sops.secrets."actual-budget-mcp-password" = { };
    sops.secrets."actual-budget-mcp-sync-id" = { };

    # Mealie MCP credentials, consumed by the Mealie MCP wrapper (uvx) in
    # ../mcp/mealie.nix via a direct secret path (not an env template).
    sops.secrets."mealie-api-key" = { };

    # Dashboard credentials live in their own secret so they never land
    # in the agent process environment (and vice versa).
    sops.secrets."hermes-dashboard" = { };

    # Secrets that are still one value each keep the template mechanism.
    sops.templates."hermes-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        KARAKEEP_API_KEY=${config.sops.placeholder."karakeep-api-key"}
      '';
    };

    # sops-nix renders these via its `sops-nix` user service, triggered by its
    # HM activation entry `home.activation."sops-nix"` and again at user-unit
    # start. Upstream's hermesAgentSetup (which merges environmentFiles into
    # ${hermesHome}/.env) is pinned after the sops-nix activation entry below,
    # so the rendered files exist by then.
    # Values never enter the Nix store. 0600, owned by the HM user.
    # NOTE: pinned sops-nix home-manager templates module (rev fbf75929,
    # modules/home-manager/templates.nix) defines no restartUnits option, so
    # after a secret rotation the consuming units (hermes-agent /
    # hermes-backend) must still be restarted to re-read the rotated
    # EnvironmentFiles / .env; the Unit.After ordering below only guarantees
    # start ordering, not pickup of rotated values.
    sops.templates."hermes-agent-env" = {
      content = config.sops.placeholder."hermes";
      mode = "0600";
    };

    sops.templates."hermes-dashboard-env" = {
      content = config.sops.placeholder."hermes-dashboard";
      mode = "0600";
    };

    # Start-ordering guard: both units must start after the sops-nix user
    # service so rendered files (environmentFiles / dashboard env) exist at
    # first boot, when the activation restart is skipped as a no-op.
    systemd.user.services.hermes-agent.Unit.After = [ "sops-nix.service" ];
    systemd.user.services.hermes-backend.Unit.After = [ "sops-nix.service" ];

    # The dashboard reads its basic-auth env from this file; keeping it on the
    # user unit keeps dashboard credentials out of the agent's .env.
    systemd.user.services.hermes-backend.Service.EnvironmentFile = [
      config.sops.templates."hermes-dashboard-env".path
    ];

    # Direct HM activation DAG dependency: the `sops-nix` activation entry
    # (which synchronously `systemctl --user restart`s the sops-nix user
    # service, and thus renders all sops secrets/templates) now runs strictly
    # before hermesAgentSetup, so the files listed in environmentFiles under
    # ~/.config/sops-nix/secrets/rendered/ exist before that activation merges
    # them into ${hermesHome}/.env.
    #
    # Home Manager 26.11's `home.activation` (`dagOf types.str`) entries cannot
    # be edge-extended from a sibling module (partial `.after`/`.before` defs
    # are re-wrapped as `data` and fail type checks), so the edge is added by
    # re-declaring sops-nix's own entry verbatim. The script is copied from
    # `inputs.sops-nix`'s home-module (`modules/home-manager/sops.nix`,
    # pinned in flake.lock); if that input updates, keep this in sync.
    home.activation."sops-nix" = lib.mkIf (config.sops.secrets != { }) (
      lib.hm.dag.entryBefore [ "hermesAgentSetup" ] ''
        systemdStatus=$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1 || true)

        if [[ $systemdStatus == 'running' || $systemdStatus == 'degraded' ]]; then
          ${config.systemd.user.systemctlPath} restart --user sops-nix
        else
          echo "User systemd daemon not running. Probably executed on boot where no manual start/reload is needed."
        fi

        unset systemdStatus
      ''
    );

    # Upstream HM user units the secret files feed (guard against silent drift
    # upstream); evaluated at build time.
    assertions =
      map
        (name: {
          assertion = config.systemd.user.services ? ${name};
          message = "modules/services/hermes-agent/secrets: no such systemd user service is defined for this home: ${name}";
        })
        [
          "hermes-agent"
          "hermes-backend"
        ];
  };
}
