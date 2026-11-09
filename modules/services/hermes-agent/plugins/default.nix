{ ... }:
{
  services.hermes-agent.settings.plugins.enabled = [
    "langfuse"
    "holographic"
    "homeassistant"
    "advanced-delegation"
    "bubblewrap"
    "memory-wiki"
  ];

  imports = [
    ./langfuse
    ./holographic
    ./homeassistant
    ./advanced-delegation
    ./bubblewrap
    ./memory-wiki
  ];
}
