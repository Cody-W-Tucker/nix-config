{
  pkgs,
  lib,
  inputs,
  nodejs ? pkgs.nodejs_22,
}:
let
  osirisSrc = inputs.osiris;
  # The Pythia overlay lives at integrations/osiris inside the pinned Pythia
  # source. We copy its new files and apply its existing-file modifications
  # deterministically at build time (see prePatch).
  pythiaOverlay = inputs.pythia + "/integrations/osiris";
  overlayMap = ./patches/overlay-map.txt;
  patchDir = ./patches;
in
pkgs.buildNpmPackage {
  pname = "osiris-dashboard";
  version = "0.1.0";

  # `flake = false` input → a plain source tree handed to buildNpmPackage.
  src = osirisSrc;

  # Node 22 as required.
  nodejs = nodejs;

  # Hash of the npm dependency tree, built from the pinned package-lock.json
  # (the Pythia overlay does not modify dependencies).
  npmDepsHash = "sha256-vDSTRlf+QzCHh0Qz+bFThhd71FJ7UVn3LIjIe9+4SiQ=";

  nativeBuildInputs = [ pkgs.python3 ];

  # Do not run the test suite during the package build.
  doCheck = false;

  # ── Deterministic overlay application (runs before npm install / build) ──
  prePatch = ''
        echo "→ Applying Pythia integrations/osiris overlay onto Osiris source"

        # 1) New files: copy every overlay file into its documented destination.
        while read -r rel dest; do
          # Skip blank lines and comments.
          [ -z "$rel" ] && continue
          case "$rel" in
            \#*) continue ;;
          esac
          mkdir -p "$(dirname "$dest")"
          cp -f "${pythiaOverlay}/$rel" "$dest"
        done < ${overlayMap}

        # 1b) Osiris ships CRLF source; normalize to LF so the LF patches and the
        #     apply-page.py (LF exact-string anchors) apply deterministically.
        find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.json' -o -name '*.css' -o -name '*.scss' \) -exec sed -i 's/\r$//' {} +

        # 1c) Compatibility shim: the original Osiris routes (e.g. cloudflare-radar)
        #     import `centroidFor` from @/lib/countryCentroids, but the Pythia
        #     overlay replaces that module with one exposing byIso2/byIso3/byName.
        #     Re-export `centroidFor` so existing routes keep working without
        #     touching the read-only Pythia source.
        if [ -f src/lib/countryCentroids.ts ]; then
          cat >> src/lib/countryCentroids.ts <<'TS'

    export function centroidFor(code?: string): [number, number] | null {
      if (!code) return null;
      return byIso2(code) || byIso3(code) || byName(code) || null;
    }
    TS
        fi

        # 1d) The dashboard is a live, client-heavy app; the Pythia overlay's
        #     default-on map layers (hurricanes/flood/volcanoes/orbits3d) are not
        #     SSR-safe at build-time prerender. Force dynamic rendering so
        #     `next build` does not statically prerender "/" (and other routes).
        #     The standalone server still SSRs per request at runtime. layout.tsx
        #     is a server component, so this route-segment export is honored.
        cat >> src/app/layout.tsx <<'TS'

    export const dynamic = 'force-dynamic';
    TS

        # 2) Existing-file modifications (the prose-documented edits), as patches.
        for p in next.config layout manifest layerpanel osirismap; do
          echo "  patch: $p"
          patch -p1 --no-backup-if-mismatch < ${patchDir}/$p.patch
        done

        # 3) page.tsx wiring (imports, state, theme persistence, engine fetch,
        #    deck/tickers/floating-window mounts) — applied via a script so a
        #    missed anchor fails the build loudly instead of silently.
        echo "  patch: page"
        ${pkgs.python3}/bin/python3 ${patchDir}/apply-page.py

        # 4) markets route: drop the fake browser User-Agent (Yahoo 429s it).
        substituteInPlace src/app/api/markets/route.ts \
          --replace "const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';" \
                     "const UA = 'osiris/0.1 (+https://osirisai.live)';"

        # 5) Brand CSS additions (purely additive — safe under any build).
        cat >> src/app/globals.css <<'CSS'

        /* ── PYTHIA brand / theme tokens (Osiris overlay) ── */
        :root { --horizon-year: #7E97E8; }
        @keyframes pythia-sweep { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }
        .pythia-progress { position: relative; height: 2px; overflow: hidden; background: rgba(212,175,55,0.12); }
        .pythia-progress::after { content: ""; position: absolute; inset: 0; width: 40%; background: linear-gradient(90deg, transparent, var(--gold-primary), transparent); animation: pythia-sweep 1.1s linear infinite; }
        body.theme-light { background: #f4f6fb; color: #0b1020; }
        body.theme-light .glass-panel, body.theme-light .glass-panel-sm { background: rgba(255,255,255,0.7); color: #0b1020; }
        .pythia-ticker-bg { background: linear-gradient(90deg, rgba(212,175,55,0.08), transparent); }
    CSS
  '';

  # Next.js build must not phone home for telemetry.
  NEXT_TELEMETRY_DISABLED = 1;

  # ── Install the Next standalone server + assets ──
  installPhase = ''
    mkdir -p $out
    cp -r .next/standalone/. $out/
    mkdir -p $out/.next
    cp -r .next/static $out/.next/static
    cp -r public $out/public

    if [ ! -e "$out/server.js" ]; then
      echo "ERROR: expected $out/server.js from next standalone build" >&2
      find $out -maxdepth 2 -name 'server.js' >&2
      exit 1
    fi
  '';

  meta = with lib; {
    description = "Osiris dashboard with the Pythia oracle overlay (Next.js 16).";
    homepage = "https://github.com/simplifaisoul/osiris";
    license = licenses.mit;
    mainProgram = "server.js";
  };
}
