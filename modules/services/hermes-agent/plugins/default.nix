{ ... }:
{
  services.hermes-agent.settings.plugins.enabled = [
    "langfuse"
    "homeassistant"
    "advanced-delegation"
    "bubblewrap"
    "memory-wiki"
  ];

  imports = [
    ./langfuse
    ./hindsight
    ./homeassistant
    ./advanced-delegation
    ./bubblewrap
    ./memory-wiki
  ];
}
