import { NextResponse } from 'next/server';
import { isRateLimited, getClientIp } from '@/lib/ssrf-guard';

export const dynamic = 'force-dynamic';

/**
 * Entity graph expansion for the Osiris Entity Intel panel.
 *
 * Root-cause fix:
 *   Upstream Osiris proxies this route to a standalone `osiris-intel`
 *   service (INTEL_URL, default http://osiris-intel:4000). That service is
 *   NOT part of this Nix/Pythia deployment, so the Graph panel always
 *   returned 502 "Intelligence layer unavailable" (the host doesn't even
 *   resolve). In this stack the intelligence layer is the local Pythia
 *   engine, which is OpenAI-style and reachable at PYTHIA_ENGINE_URL. We
 *   therefore resolve through Pythia by default, and only use a standalone
 *   INTEL_URL when one is explicitly configured. No external API key is
 *   required and the configured LLM model/provider is unchanged.
 */

const INTEL_URL = process.env.INTEL_URL || (
  process.env.NODE_ENV === 'production'
    ? 'http://osiris-intel:4000'
    : 'http://localhost:4000'
);

// Local Pythia oracle engine (set by the osiris systemd unit). This is the
// intelligence layer available in this deployment.
const ENGINE_URL = (process.env.PYTHIA_ENGINE_URL || 'http://localhost:8088').replace(/\/$/, '');

const ALLOWED_TYPES = new Set([
  'aircraft', 'vessel', 'company', 'person', 'ip', 'country', 'event', 'sanction',
]);

// Strict JSON-only contract so the LLM output is machine-parseable.
const PROMPT = `You are an open-source intelligence graph resolver. Given an entity (type and id/name), return a knowledge graph of related entities as STRICT JSON only — no prose, no markdown code fences.

Schema:
{
  "nodes": [ { "id": "<type>:<unique>", "label": "<human name>", "type": "aircraft|vessel|company|person|country|event|sanction|ip", "properties": {} } ],
  "links": [ { "source": "<node id>", "target": "<node id>", "label": "<relationship>" } ]
}
Rules:
- The first node MUST be the root entity, with id "<type>:<id>" and label "<label>".
- Add 4-8 closely related entities (parent org, founders, subsidiaries, HQ country, key products, regulators, related events).
- Use ONLY the listed type values.
- Keep ids unique, e.g. "person:Sam Altman", "company:Microsoft", "country:United States".
- Every link must reference existing node ids; label is a short relationship phrase (e.g. "CEO of", "headquartered in").
Return only the JSON object.`;

function extractGraph(text: string): { nodes: any[]; links: any[] } | null {
  if (!text) return null;
  let s = text.trim();
  // Strip markdown code fences if the model added them.
  s = s.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '');
  const first = s.indexOf('{');
  const last = s.lastIndexOf('}');
  if (first === -1 || last === -1 || last <= first) return null;
  const json = s.slice(first, last + 1);
  try {
    const parsed = JSON.parse(json);
    if (!parsed || !Array.isArray(parsed.nodes)) return null;
    const nodes = parsed.nodes
      .filter((n: any) => n && typeof n.id === 'string' && typeof n.label === 'string')
      .map((n: any) => ({
        id: String(n.id),
        label: String(n.label),
        type: ALLOWED_TYPES.has(n.type) ? n.type : 'company',
        properties: n.properties && typeof n.properties === 'object' ? n.properties : {},
      }));
    const ids = new Set(nodes.map((n: any) => n.id));
    const links = Array.isArray(parsed.links)
      ? parsed.links
          .filter((l: any) => l && ids.has(l.source) && ids.has(l.target) && typeof l.label === 'string')
          .map((l: any) => ({ source: String(l.source), target: String(l.target), label: String(l.label) }))
      : [];
    return { nodes, links };
  } catch {
    return null;
  }
}

async function resolveViaPythia(type: string, id: string, label: string): Promise<{ nodes: any[]; links: any[] }> {
  const message = `Expand the entity graph for:\n- type: ${type}\n- id: ${id}\n- label: ${label}`;
  const res = await fetch(`${ENGINE_URL}/chat`, {
    method: 'POST',
    signal: AbortSignal.timeout(60000),
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: `${PROMPT}\n\n${message}` }),
  });
  if (!res.ok) throw new Error(`Pythia engine returned ${res.status}`);
  const data = await res.json().catch(() => ({}));
  const answer = typeof data?.answer === 'string' ? data.answer : null;
  const graph = extractGraph(answer);
  if (!graph || graph.nodes.length === 0) throw new Error('Pythia returned no usable graph');
  return graph;
}

async function resolveViaIntel(params: URLSearchParams, clientIp: string): Promise<{ nodes: any[]; links: any[] }> {
  const res = await fetch(`${INTEL_URL}/resolve?${params}`, {
    signal: AbortSignal.timeout(15000),
    headers: { 'X-Forwarded-For': clientIp },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Intel layer returned ${res.status}`);
  }
  const data = await res.json();
  return { nodes: data.nodes || [], links: data.links || [] };
}

export async function GET(req: Request) {
  const clientIp = getClientIp(req);
  if (isRateLimited(clientIp, 30, 60_000)) {
    return NextResponse.json({ error: 'Rate limit exceeded' }, { status: 429 });
  }

  const { searchParams } = new URL(req.url);
  const type = (searchParams.get('type') || '').toLowerCase().trim();
  const id = (searchParams.get('id') || '').trim();

  if (!type || !ALLOWED_TYPES.has(type)) {
    return NextResponse.json(
      { error: `Invalid type. Allowed: ${[...ALLOWED_TYPES].join(', ')}` },
      { status: 400 },
    );
  }
  if (!id || id.length < 2 || id.length > 200) {
    return NextResponse.json({ error: 'Invalid id (2-200 chars)' }, { status: 400 });
  }

  const params = new URLSearchParams({ type, id });
  // Forward extra aircraft properties to the intel brain
  for (const key of ['registration', 'model', 'icao24']) {
    const val = searchParams.get(key);
    if (val) params.set(key, val);
  }

  // An explicitly configured standalone intel backend wins; otherwise the
  // local Pythia engine is the intelligence layer for this deployment.
  const useIntel = Boolean(process.env.INTEL_URL);

  try {
    const graph = useIntel
      ? await resolveViaIntel(params, clientIp)
      : await resolveViaPythia(type, id, searchParams.get('label') || id);
    return NextResponse.json(graph, {
      headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=7200' },
    });
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    console.error('[OSIRIS] Entity expand error:', detail);
    return NextResponse.json(
      {
        error: `Intelligence layer unavailable (${detail}). The graph resolver uses the local Pythia engine at ${ENGINE_URL}; ensure it is running.`,
        nodes: [],
        links: [],
      },
      { status: 502 },
    );
  }
}
