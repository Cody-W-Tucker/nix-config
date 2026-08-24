{
  config,
  lib,
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  # WORKAROUND (2026-08-23): Karakeep's systemd units crash at startup because the
  # current nixpkgs `nodejs_24` (24.19.x) breaks better-sqlite3 on cleanup.
  # Upstream issue: https://github.com/karakeep-app/karakeep/issues/2989
  # REVIEW-BY: 2026-11-23 — drop `package` once stable karakeep no longer builds
  # against the broken nodejs 24.19.x range (or moves to nodejs_22 LTS).
  prior = inputs.nixpkgs-prior.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Self-expiry: the override is obsolete once the *default* (consumer's stable)
  # karakeep no longer builds against the broken 24.19.x nodejs range. We inspect
  # the default package, not the override, so the warning only fires after
  # upstream reverts the node bump.
  defaultNode = lib.findFirst (
    d: (d.name or "") != "" && (builtins.match "nodejs-.*" d.name != null)
  ) null (pkgs.karakeep.nativeBuildInputs or [ ] ++ pkgs.karakeep.buildInputs or [ ]);
  defaultNodeBroken =
    defaultNode != null
    && (
      let
        v = defaultNode.version;
      in
      lib.versionAtLeast v "24.19.0" && lib.versionOlder v "24.20.0"
    );
  karakeepPinObsolete = defaultNode != null && !defaultNodeBroken;
in
{
  services.karakeep = {
    enable = true;
    package = prior.karakeep;
    extraEnvironment = {
      PORT = "3005";
      DB_WAL_MODE = "true"; # This should improve the performance of the database.
      DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      OPENAI_API_KEY = "blank";
      OPENAI_BASE_URL = "http://nas:8081/v1";

      INFERENCE_TEXT_MODEL = "qwen-3.5-4b";
      OCR_USE_LLM = "true";
      INFERENCE_IMAGE_MODEL = "qwen-3.5-4b";
      INFERENCE_CONTEXT_LENGTH = "8192";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";

      EMBEDDING_ENABLE_AUTO_INDEXING = "true";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
      EMBEDDING_DIMENSIONS = "1024";
      EMBEDDING_CONTEXT_LENGTH = "8192";
      MAX_ASSET_SIZE_MB = "100";
    };
  };

  warnings =
    lib.optional (config.services.karakeep.enable && karakeepPinObsolete)
      "Karakeep no longer builds against the broken nodejs 24.19.x range (now ${defaultNode.version}); remove the nixpkgs-prior pin in modules/nas/karakeep.nix.";

  services.nginx.virtualHosts = mkNginxVhost {
    host = "karakeep.homehub.tv";
    port = 3005;
    proxyWebsockets = true;
  };
}
