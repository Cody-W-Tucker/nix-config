{
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.cognitive-assistant.nixosModules.langfuse-review-queue ];

  # Reuse the encrypted Langfuse API env already consumed by OpenCode.
  sops.secrets."opencode-langfuse-env" = {
    owner = "codyt";
    mode = "0400";
  };

  services.langfuse-review-queue = {
    enable = true;
    baseUrl = "https://langfuse.homehub.tv";
    environmentFile = config.sops.secrets."opencode-langfuse-env".path;
  };

  systemd.services.langfuse-review-queue.serviceConfig.User = "codyt";
}
