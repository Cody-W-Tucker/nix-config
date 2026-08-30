{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
}:
buildNpmPackage rec {
  pname = "gods-eye-view";
  # Pinned upstream commit; the version string is human-readable only.
  version = "0.0.0-314a0e1";

  src = fetchFromGitHub {
    owner = "bilawalsidhu";
    repo = "gods-eye-view";
    rev = "314a0e1c2ef668cb110674b737e19a44ff6fc1ef";
    hash = "sha256-jEdqbMfX5M7U8QZTaCzBZDzHD85PY2KmxHBshOvG65Q=";
  };

  nodejs = nodejs_24;

  # Reproducible dependency install from the upstream-committed package-lock.json.
  npmDepsHash = "sha256-oaxPdSeJi8GWMg+q7RopAbdidbr2HaWpXylSnsPOCfs=";

  # Puppeteer is a heavy CI-only dev-dependency; skip its Chromium download.
  # It is not needed by the Vite dev server or the production build.
  env = {
    PUPPETEER_SKIP_DOWNLOAD = "1";
  };

  # Allow the dashboard to be reachable as watch.homehub.tv through the reverse
  # proxy without widening upstream's restricted dev-server host list. Only this
  # single hostname is appended; the upstream `localhost` / `127.0.0.1` / `.local`
  # entries and the all-interfaces `true` branch are left untouched.
  postPatch = ''
    substituteInPlace vite.config.js \
      --replace-fail "['localhost', '127.0.0.1', '.local']," \
      "['localhost', '127.0.0.1', '.local', 'watch.homehub.tv'],"
  '';

  # Keep the full runtime source tree + node_modules so the systemd service can
  # launch the Vite dev server (`npm run dev` -> `vite`). Upstream brokers and
  # proxies third-party APIs through Vite's configureServer, so the dev server
  # (not a static `vite preview`) is what we run. The default npmBuildHook still
  # runs `vite build` as a build-time validation.
  #
  # Vite writes three caches under process.cwd():
  #   - .gev-cache           (upstream app data cache)
  #   - node_modules/.vite   (Vite transform cache)
  #   - node_modules/.vite-temp (Vite config-bundling temp dir, written before
  #     the dev server starts)
  # The store path is immutable, so each is symlinked into the persistent
  # StateDirectory (/var/lib/gods-eye-view), provisioned by the NAS module's
  # systemd.tmpfiles rules. This keeps the store read-only while the caches
  # stay writable across rebuilds.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/gods-eye-view"
    cp -r . "$out/share/gods-eye-view/"

    rm -rf "$out/share/gods-eye-view/.gev-cache"
    ln -sfn /var/lib/gods-eye-view/.gev-cache "$out/share/gods-eye-view/.gev-cache"

    rm -rf "$out/share/gods-eye-view/node_modules/.vite"
    ln -sfn /var/lib/gods-eye-view/.vite "$out/share/gods-eye-view/node_modules/.vite"

    rm -rf "$out/share/gods-eye-view/node_modules/.vite-temp"
    ln -sfn /var/lib/gods-eye-view/.vite-temp "$out/share/gods-eye-view/node_modules/.vite-temp"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Real-time intelligence console for planet Earth — 3D globe with live data and voice control";
    homepage = "https://github.com/bilawalsidhu/gods-eye-view";
    license = licenses.mit;
  };
}
