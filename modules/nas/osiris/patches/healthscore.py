#!/usr/bin/env python3
"""Patch the copied GlobalHealthScore component so it can be dismissed.

The component is copied verbatim from the Pythia overlay at build time
(modules/nas/osiris/package.nix prePatch, via overlay-map.txt). This script
deterministically:
  - adds `X` to the lucide-react import,
  - accepts an optional `onClose` prop,
  - renders a small, accessible close (X) button when `onClose` is provided.

The outer `className` (including the desktop `md:left-[60px]` offset that
package.nix substitutes in later) is intentionally left untouched, so that
substitution still matches and the sidebar-clear offset is preserved.
"""
import sys

P = "src/components/GlobalHealthScore.tsx"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.stderr.write(f"ANCHOR NOT FOUND EXACTLY ({count} expected, {n} seen):\n{old!r}\n")
        sys.exit(1)
    s = s.replace(old, new, 1)


# 1) lucide-react: add X for the close affordance.
rep(
    "import { ChevronDown } from 'lucide-react';",
    "import { ChevronDown, X } from 'lucide-react';",
)

# 2) Accept an optional onClose prop.
rep(
    "export default function GlobalHealthScore() {",
    "export default function GlobalHealthScore({ onClose }: { onClose?: () => void }) {",
)

# 3) Render a small accessible close button at the panel's top-right corner.
#    Positioned just outside the badge so it never covers the expand chevron
#    nor the 48px desktop sidebar.
rep(
    '    <div className="fixed z-[300] top-[104px] left-3 w-[172px] font-mono">\n      <button onClick={() => setOpen(o => !o)}',
    '''    <div className="fixed z-[300] top-[104px] left-3 w-[172px] font-mono">
      {onClose && (
        <button
          type="button"
          onClick={onClose}
          aria-label="Dismiss Global Health Score"
          title="Dismiss Global Health Score"
          className="absolute -top-2.5 -right-2.5 z-10 w-5 h-5 flex items-center justify-center rounded-full bg-black/40 border border-white/15 text-white/70 hover:bg-black/70 hover:text-white transition-colors"
        >
          <X className="w-3 h-3" />
        </button>
      )}
      <button onClick={() => setOpen(o => !o)}''',
)

open(P, "w", encoding="utf-8").write(s)
sys.stderr.write("healthscore.py: GlobalHealthScore dismiss affordance applied\n")
