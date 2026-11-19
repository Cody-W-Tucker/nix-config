{
  # llama-swap model router: the service module (_impl, incl. its python servers and model
  # catalog) plus this repo's model selection (_nas-models.nix). Only nas runs local AI.
  den.aspects.llama-swap.nixos =
    { config, ... }:
    {
      imports = [
        ./_impl
        ./_nas-models.nix
      ];

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ config.services.llama-swap.port ];
    };
}
