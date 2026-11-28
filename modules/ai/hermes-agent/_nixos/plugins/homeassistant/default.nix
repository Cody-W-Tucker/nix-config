{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeAssistantPlugin = import ../lib/build-plugin.nix pkgs {
    name = "homeassistant";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
    requiresHermes = "0.21.5";
  };
in
{
  systemd.services.hermes-agent.preStart = ''
    ln -sfn ${homeAssistantPlugin} ${config.services.hermes-agent.stateDir}/.hermes/plugins/homeassistant
  '';
  codyos.hermes-agent.egress.loopbackPorts = [ 8123 ];
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 900 [ homeAssistantPlugin ];
    environment.HASS_URL = "http://127.0.0.1:8123";
  };
}
