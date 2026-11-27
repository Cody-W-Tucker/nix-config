{
  config,
  inputs,
  ...
}:
let
  inherit (config.codyos.site) domain;
in
{
  imports = [ inputs.cognitive-assistant.nixosModules.langfuse-review-queue ];

  sops.secrets."opencode-langfuse-env" = {
    owner = config.codyos.site.user.name;
    mode = "0400";
  };

  services.langfuse-review-queue = {
    enable = true;
    baseUrl = "https://langfuse.${domain}";
    environmentFile = config.sops.secrets."opencode-langfuse-env".path;
  };

  systemd.services.langfuse-review-queue.serviceConfig.User = config.codyos.site.user.name;
}
