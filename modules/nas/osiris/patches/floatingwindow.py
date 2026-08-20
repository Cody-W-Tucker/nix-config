#!/usr/bin/env python3
"""Apply the Pythia overlay's FloatingWindow default-geometry fix deterministically.

The overlay's FloatingWindow requires `initial: { x, y, w, h }` and reads
initial.x / initial.y / initial.w / initial.h at construction. The dashboard
mounts five instances (filings / contracts / feeds / ticker / satellite) WITHOUT
passing `initial`, which crashes SSR on `initial.x`. This makes the geometry
optional with a component-level default so absent callers never crash.

Performed as an exact, assertable string replacement so a missed anchor fails
the build loudly instead of silently degrading.
"""
import sys

P = "src/components/FloatingWindow.tsx"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.stderr.write(f"ANCHOR NOT FOUND EXACTLY ({count} expected, {n} seen):\n{old!r}\n")
        sys.exit(1)
    s = s.replace(old, new, 1)


rep(
    """type Props = {
  title: string;
  icon?: React.ReactNode;
  initial: { x: number; y: number; w: number; h: number };
  z: number;
  onClose: () => void;
  onFocus: () => void;
  headerRight?: React.ReactNode;
  children: React.ReactNode;
};

export default function FloatingWindow({ title, icon, initial, z, onClose, onFocus, headerRight, children }: Props) {""",
    """type Geometry = { x: number; y: number; w: number; h: number };
// Default geometry so callers that omit `initial` (the dashboard mounts five
// FloatingWindow instances without it) never crash on initial.x/y/w/h.
const DEFAULT_GEOMETRY: Geometry = { x: 80, y: 80, w: 480, h: 360 };

type Props = {
  title?: string;
  icon?: React.ReactNode;
  initial?: Geometry;
  z?: number;
  onClose: () => void;
  onFocus?: () => void;
  headerRight?: React.ReactNode;
  children: React.ReactNode;
};

export default function FloatingWindow({ title, icon, initial = DEFAULT_GEOMETRY, z = 50, onClose, onFocus = () => {}, headerRight, children }: Props) {""",
)

open(P, "w", encoding="utf-8").write(s)
sys.stderr.write("floatingwindow.py: default geometry applied\n")
