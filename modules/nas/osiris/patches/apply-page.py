#!/usr/bin/env python3
"""Apply the Pythia overlay's page.tsx existing-file modifications deterministically.

The prose in integrations/osiris/INSTALL.md describes these edits; this script
performs them as exact, assertable string replacements so a failing edit fails
loudly instead of silently degrading the build.
"""
import io, sys

P = "src/app/page.tsx"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.stderr.write(f"ANCHOR NOT FOUND EXACTLY ({count} expected, {n} seen):\n{old!r}\n")
        sys.exit(1)
    s = s.replace(old, new, 1)


# 1) lucide-react icons used by the new tool-strip buttons.
#    The pinned Osiris import line differs from the overlay's reference, so we
#    add exactly the icons the inserted JSX uses into the real import line.
rep(
    "import { Layers, BarChart3, Newspaper, Search, X, Globe, MapPinned, Route, Radar, Satellite, Moon, ExternalLink, AlertTriangle, Activity, Database, Wifi, Play, Network, Crosshair, Bluetooth, Pentagon, Radio } from 'lucide-react';\n",
    "import { Layers, BarChart3, Newspaper, Search, X, Globe, MapPinned, Route, Radar, Satellite, Moon, ExternalLink, AlertTriangle, Activity, Database, Wifi, Play, Network, Crosshair, Bluetooth, Pentagon, Radio, Eye, Landmark, Coins, MonitorPlay, Rss } from 'lucide-react';\n",
)

# 2) Import the new Pythia components.
rep(
    "import LiveAlerts from '@/components/LiveAlerts';\n",
    """import LiveAlerts from '@/components/LiveAlerts';
import PythiaStatus from '@/components/PythiaStatus';
import PythiaPanel from '@/components/PythiaPanel';
import PanelModal from '@/components/PanelModal';
import MarketTicker from '@/components/MarketTicker';
import HeadlineTicker from '@/components/HeadlineTicker';
import GlobalHealthScore from '@/components/GlobalHealthScore';
import SignalNotifier from '@/components/SignalNotifier';
import CreditsModal from '@/components/CreditsModal';
import FloatingWindow from '@/components/FloatingWindow';
import FilingsWindow from '@/components/FilingsWindow';
import ContractsWindow from '@/components/ContractsWindow';
import FeedsWindow from '@/components/FeedsWindow';
import SatelliteView from '@/components/SatelliteView';
import TickerWindow from '@/components/TickerWindow';
""",
)

# 3) New UI state.
rep(
    "  const [mobilePanel, setMobilePanel] = useState<'layers'|'markets'|'intel'|'search'|'recon'|'remote'|null>(null);\n",
    """  const [mobilePanel, setMobilePanel] = useState<'layers'|'markets'|'intel'|'search'|'recon'|'remote'|null>(null);
  const [showPythia, setShowPythia] = useState(false);
  const [showCredits, setShowCredits] = useState(false);
  const [win, setWin] = useState<null | 'filings' | 'contracts' | 'feeds' | 'ticker' | 'satellite'>(null);
  const [pythiaPredictions, setPythiaPredictions] = useState<any>(null);
""",
)

# 4) Boot-default the new map layers (forecast rings / hazards / 3D altitude).
rep(
    "    cf_attacks: false,\n  });",
    """    cf_attacks: false,
    predictions: true,
    predictions_all: false,
    hurricanes: true,
    flood: true,
    volcanoes: true,
    orbits3d: true,
  });""",
)

# 5) Theme: persist the chosen PYTHIA theme to localStorage (key 'pythia-theme').
rep(
    """  useEffect(() => {
    document.body.className = osirisTheme === 'core' ? '' : `theme-${osirisTheme}`;
  }, [osirisTheme]);""",
    """  useEffect(() => {
    try {
      const saved = localStorage.getItem('pythia-theme');
      if (saved === 'light' || saved === 'ghost') setOsirisTheme(saved);
    } catch { /* ignore */ }
  }, []);
  useEffect(() => {
    document.body.className = osirisTheme === 'core' ? '' : `theme-${osirisTheme}`;
    try { localStorage.setItem('pythia-theme', osirisTheme); } catch { /* ignore */ }
  }, [osirisTheme]);""",
)

# 6) Poll the Pythia engine for predictions → deck + map rings.
rep(
    "  // CCTV: loaded once on layer toggle via layerFetchedRef (no viewport polling)\n",
    """  // ── PYTHIA oracle forecasts → deck + map rings ──
  useEffect(() => {
    let alive = true;
    const load = () => {
      fetch('/api/engine/predictions')
        .then((r) => (r.ok ? r.json() : null))
        .then((d) => {
          if (!alive || !d) return;
          dataRef.current = { ...dataRef.current, pythia_predictions: d.predictions || d };
          setPythiaPredictions(d);
          setDataVersion((v) => v + 1);
        })
        .catch(() => {});
    };
    load();
    const iv = setInterval(load, 30000);
    return () => { alive = false; clearInterval(iv); };
  }, []);

  // CCTV: loaded once on layer toggle via layerFetchedRef (no viewport polling)
""",
)

# 7) Render PythiaStatus top-right.
rep(
    "      </motion.div>\n\n      {/* ── MOBILE: Compact top status ── */}",
    "      </motion.div>\n\n      <PythiaStatus />\n\n      {/* ── MOBILE: Compact top status ── */}",
)

# 8) Render the always-on Global Health Score (top-left) over the map.
rep(
    "      </ErrorBoundary>\n\n      {/* ── DIRECTIONS",
    "      </ErrorBoundary>\n\n      {!isMobile && <GlobalHealthScore />}\n\n      {/* ── DIRECTIONS",
)

# 9) Bottom tickers + the invisible SignalNotifier poller.
rep(
    "      {/* ── GLOBAL STATUS TICKER (bottom) ── */}\n      <GlobalStatusBar />",
    """      <MarketTicker />
      <HeadlineTicker />
      <SignalNotifier />

      {/* ── GLOBAL STATUS TICKER (bottom) ── */}
      <GlobalStatusBar />""",
)

# 10) Tool-strip buttons: PYTHIA deck + Filings / Contracts / Signals / Display.
rep(
    "        {/* Separator */}\n        <div className=\"w-4 h-px bg-white/10 mx-auto\" />\n\n        {/* ── ARCGIS INTEL ── */}",
    """        <div className="relative group">
          <button onClick={() => setShowPythia((v) => !v)} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${showPythia ? 'bg-[var(--gold-primary)]/20' : 'hover:bg-white/10'}`} title="PYTHIA — Oracle Deck">
            <Eye className={`w-4 h-4 ${showPythia ? 'text-[var(--gold-primary)]' : 'text-white/60'}`} />
          </button>
          <span className="absolute right-11 top-1/2 -translate-y-1/2 px-2 py-1 text-[10px] font-mono tracking-wider text-white/80 bg-black/80 backdrop-blur-sm rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">PYTHIA</span>
        </div>

        <div className="relative group">
          <button onClick={() => setWin((w) => (w === 'filings' ? null : 'filings'))} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${win === 'filings' ? 'bg-[var(--gold-primary)]/20' : 'hover:bg-white/10'}`} title="SEC Filings Tape">
            <Landmark className={`w-4 h-4 ${win === 'filings' ? 'text-[var(--gold-primary)]' : 'text-white/60'}`} />
          </button>
          <span className="absolute right-11 top-1/2 -translate-y-1/2 px-2 py-1 text-[10px] font-mono tracking-wider text-white/80 bg-black/80 backdrop-blur-sm rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">FILINGS</span>
        </div>

        <div className="relative group">
          <button onClick={() => setWin((w) => (w === 'contracts' ? null : 'contracts'))} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${win === 'contracts' ? 'bg-[var(--gold-primary)]/20' : 'hover:bg-white/10'}`} title="Federal Money Tape">
            <Coins className={`w-4 h-4 ${win === 'contracts' ? 'text-[var(--gold-primary)]' : 'text-white/60'}`} />
          </button>
          <span className="absolute right-11 top-1/2 -translate-y-1/2 px-2 py-1 text-[10px] font-mono tracking-wider text-white/80 bg-black/80 backdrop-blur-sm rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">CONTRACTS</span>
        </div>

        <div className="relative group">
          <button onClick={() => setWin((w) => (w === 'feeds' ? null : 'feeds'))} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${win === 'feeds' ? 'bg-[var(--gold-primary)]/20' : 'hover:bg-white/10'}`} title="Signals">
            <Rss className={`w-4 h-4 ${win === 'feeds' ? 'text-[var(--gold-primary)]' : 'text-white/60'}`} />
          </button>
          <span className="absolute right-11 top-1/2 -translate-y-1/2 px-2 py-1 text-[10px] font-mono tracking-wider text-white/80 bg-black/80 backdrop-blur-sm rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">SIGNALS</span>
        </div>

        <div className="relative group">
          <button onClick={() => window.open('/tv')} className="w-8 h-8 rounded-full flex items-center justify-center transition-colors hover:bg-white/10" title="Display Mode">
            <MonitorPlay className="w-4 h-4 text-white/60" />
          </button>
          <span className="absolute right-11 top-1/2 -translate-y-1/2 px-2 py-1 text-[10px] font-mono tracking-wider text-white/80 bg-black/80 backdrop-blur-sm rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">DISPLAY</span>
        </div>

        {/* Separator */}
        <div className="w-4 h-px bg-white/10 mx-auto" />

        {/* ── ARCGIS INTEL ── */}""",
)

# 11) Mount the deck modal, credits modal, and the floating windows.
rep(
    "      {/* ── OVERLAYS ── */}",
    """      <PanelModal open={showPythia} onClose={() => setShowPythia(false)} title="PYTHIA — ORACLE">
        <PythiaPanel embedded onLocate={(lat: number, lng: number) => setFlyToLocation({ lat, lng, ts: Date.now() })} />
      </PanelModal>

      <CreditsModal open={showCredits} onClose={() => setShowCredits(false)} />

      {win === 'filings' && (
        <FloatingWindow kind="filings" onClose={() => setWin(null)}>
          <FilingsWindow />
        </FloatingWindow>
      )}
      {win === 'contracts' && (
        <FloatingWindow kind="contracts" onClose={() => setWin(null)}>
          <ContractsWindow />
        </FloatingWindow>
      )}
      {win === 'feeds' && (
        <FloatingWindow kind="feeds" onClose={() => setWin(null)}>
          <FeedsWindow />
        </FloatingWindow>
      )}
      {win === 'ticker' && (
        <FloatingWindow kind="ticker" onClose={() => setWin(null)}>
          <TickerWindow />
        </FloatingWindow>
      )}
      {win === 'satellite' && (
        <FloatingWindow kind="satellite" onClose={() => setWin(null)}>
          <SatelliteView />
        </FloatingWindow>
      )}

      {/* ── OVERLAYS ── */}""",
)

open(P, "w", encoding="utf-8").write(s)
sys.stderr.write("apply-page.py: all page.tsx overlays applied\n")
