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
      extraArgs = [ "--skip-build" ];
    };
  };
}
