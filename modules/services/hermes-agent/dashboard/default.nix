# Hermes Dashboard — remote web UI on port 9119.
#
# Separate process from hermes-agent.service (the messaging gateway).
# Shares HERMES_HOME for config/sessions. Requires basic auth when
# binding to a non-loopback address. Under Home Manager the dashboard is
# upstream's `hermes-backend` systemd user unit in `backend.mode =
# "dashboard"`, not a bespoke system service.
{
  config,
  lib,
  ...
}:

{
  config = {
    services.hermes-agent.backend = {
      mode = "dashboard";
      host = "0.0.0.0";
      port = 9119;
      # Keep the CLI-supplied build step off this path (matches the old
      # system unit's --skip-build).
      extraArgs = [ "--skip-build" ];
    };
  };
}
