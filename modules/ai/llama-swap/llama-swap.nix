{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.llama-swap ];

  # llama-swap model router: the service module (_impl, incl. its python servers and model
  # catalog) plus this repo's model selection (_nas-models.nix). Only nas runs local AI.
  den.aspects.llama-swap.nixos =
    { config, ... }:
    let
      history = config.services.llama-swap.speechHistory;
    in
    {
      imports = [
        ./_impl
        ./_nas-models.nix
      ];

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        config.services.llama-swap.port
        history.port
      ];

      # Transcripts, corrections and learned vocabulary; the 30-day audio is not backed up.
      nas.backups.sqlite = [
        {
          name = "speech-history";
          source = "/var/lib/llama-swap/speech-history/history.sqlite";
        }
      ];
    };
}
