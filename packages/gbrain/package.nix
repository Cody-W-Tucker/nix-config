{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  perl,
  writableTmpDirAsHomeHook,
}:

let
  rev = "6a10bad8e5892c7a84197bc4712249cb9685a4f7";
  version = "0.41.0.0";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gbrain";
  inherit version;

  src = fetchFromGitHub {
    owner = "garrytan";
    repo = "gbrain";
    inherit rev;
    hash = "sha256-XMg4E558fM0qxo1QHZ6jzxq8XODyiPulfmB0+lYTiFw=";
  };

  nodeModules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node-modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/.bun-install-cache"

      bun install --frozen-lockfile --ignore-scripts --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -r node_modules "$out/node_modules"

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-aNoLq5YN4cyJgq7XhrEVetURkVN0nhpG7zyCp3gkUvw=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
    perl
  ];

  dontConfigure = true;

  postPatch = ''
    cp -r ${finalAttrs.nodeModules}/node_modules ./node_modules
    chmod -R +w node_modules
    patchShebangs --build node_modules

    perl -0pi -e 's@\n  // Tier 3: provider not known to support custom dims at all\.\n@\n  // User-provided-model recipes (llama-server, litellm) require an explicit\n  // dimension at init time but do not ship a fixed dims allowlist. Trust the\n  // operator-provided width here and let runtime embedding-dim checks catch a\n  // bad value if the upstream server returns a different vector length.\n  if \(recipe\.touchpoints\.embedding\?\.user_provided_models === true\) {\n    return { valid: true, error: \x27\x27 };\n  }\n\n  // Tier 3: provider not known to support custom dims at all\.\n@' src/core/embedding-dim-check.ts
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/gbrain"
    cp -r . "$out/share/gbrain"

    makeWrapper ${lib.getExe bun} "$out/bin/gbrain" \
      --add-flags "run $out/share/gbrain/src/cli.ts" \
      --set-default GBRAIN_HOME "\''${XDG_DATA_HOME:-$HOME/.local/share}/gbrain"

    runHook postInstall
  '';

  meta = {
    description = "Postgres-native personal knowledge brain with hybrid RAG search";
    homepage = "https://github.com/garrytan/gbrain";
    license = lib.licenses.mit;
    mainProgram = "gbrain";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
