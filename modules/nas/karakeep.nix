{
  config,
  lib,
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:
let
  karakeepStillUsesPnpm9159 =
    config.services.karakeep.enable
    && builtins.any (dep: (dep.name or "") == "pnpm-9.15.9")
      (config.services.karakeep.package.nativeBuildInputs or []);
in
{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3005";
      DB_WAL_MODE = "true"; # This should improve the performance of the database.
      DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
      OPENAI_API_KEY = "sk-llama-swap";

      INFERENCE_TEXT_MODEL = "qwen-3.5-4b";
      OCR_USE_LLM = "true";
      INFERENCE_IMAGE_MODEL = "qwen-3.5-4b";
      INFERENCE_CONTEXT_LENGTH = "32768";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";

      EMBEDDING_ENABLE_AUTO_INDEXING = "true";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
      EMBEDDING_DIMENSIONS = "1024";
      EMBEDDING_CONTEXT_LENGTH = "8192";
      MAX_ASSET_SIZE_MB = "100";
    };
  };

  # WORKAROUND: Karakeep needs pnpm-9.15.9 but nixpkgs marks it insecure and blocks the build.
  # https://github.com/NixOS/nixpkgs/issues/539235
  # REVIEW-BY: 2026-12-27
  nixpkgs.config.permittedInsecurePackages = [ "pnpm-9.15.9" ];

  warnings = lib.optional
    (config.services.karakeep.enable && !karakeepStillUsesPnpm9159)
    "Karakeep no longer uses pnpm-9.15.9; remove the exception from permittedInsecurePackages.";

  services.nginx.virtualHosts = mkNginxVhost {
    host = "karakeep.homehub.tv";
    port = 3005;
    proxyWebsockets = true;
  };

  # Keep the catalog and captured assets together for a local restore without
  # recrawling or rerunning inference. The transient queue is intentionally skipped.
  # The catalog SQLite file is consistently exported by Restic's pre-backup step;
  # assets and settings are Restic inputs read live.
  nas.backups.sqlite = [
    {
      name = "karakeep";
      source = "/var/lib/karakeep/db.db";
      filename = "db.db";
    }
  ];
  nas.backups.dataDirectories = [
    "/var/lib/karakeep/assets"
    "/var/lib/karakeep/settings.env"
  ];
}
