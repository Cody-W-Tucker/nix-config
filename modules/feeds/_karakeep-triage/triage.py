"""Group Karakeep bookmarks by meaning and file them with Laya's classifiers.

Pass 1 embeds each bookmark locally and clusters the collection: clusters become `ai-topic:`
tags and near-identical bookmarks get `ai-duplicate`. Pass 2 asks Laya's `service-routing`
and `bookmark-kind` classifiers about each bookmark and files the answers as `ai-svc:`,
`ai-kind:` tags and the `Agency: <service>` and `CodyOS: candidates` lists.

Karakeep writes only ever add. A later different answer is logged in the state database,
never removed from Karakeep.
"""

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import logging
import math
import os
from pathlib import Path
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SERVICE_LIST = "Agency: {}"
CODYOS_LIST = "CodyOS: candidates"
DUPLICATE = 0.97  # cosine similarity at which two bookmarks are treated as the same source
TEXT_LIMIT = 4000


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class Http:
    def __init__(self, base, token=None, timeout=60):
        self.base, self.token, self.timeout = base.rstrip("/"), token, timeout

    def call(self, method, path, body=None, query=None):
        url = self.base + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = None if body is None else json.dumps(body).encode()
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        for attempt in range(4):
            request = urllib.request.Request(url, data=data, method=method, headers=headers)
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else None
            except urllib.error.HTTPError as exc:
                if exc.code in (429, 502, 503) and attempt < 3:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise


def connect(path):
    db = sqlite3.connect(path)
    db.executescript("""
        CREATE TABLE IF NOT EXISTS vectors (id TEXT PRIMARY KEY, digest TEXT, vector BLOB);
        CREATE TABLE IF NOT EXISTS answers (id TEXT PRIMARY KEY, at TEXT, answers TEXT);
        CREATE TABLE IF NOT EXISTS filed (id TEXT, target TEXT, at TEXT, PRIMARY KEY (id, target));
        CREATE TABLE IF NOT EXISTS changes (id TEXT, at TEXT, question TEXT, old TEXT, new TEXT);
        CREATE TABLE IF NOT EXISTS topics (id INTEGER PRIMARY KEY, name TEXT, centroid BLOB, created TEXT,
                                           saved_after TEXT);
    """)
    return db


def state_of(bookmark):
    """The SystemOne state: the same fields the harvest ledgers were imported with."""
    content = bookmark.get("content") or {}
    kind = content.get("type")
    title = bookmark.get("title") or content.get("title") or content.get("fileName")
    state = {"type": kind, "title": title, "url": content.get("url"), "summary": bookmark.get("summary")}
    if kind == "text" and content.get("text"):
        state["text"] = content["text"][:TEXT_LIMIT]
    state = {k: v for k, v in state.items() if v}
    # Wait for Karakeep's summary on links; a bare URL is not enough to judge.
    if not (state.get("summary") or state.get("text")):
        return None
    return state


def embed_text(state):
    return "\n".join(str(state[k]) for k in ("title", "summary", "text") if state.get(k))


def label(answer):
    """True/False from a Laya answer, or None when neither Vega nor the fallback was sure."""
    if not isinstance(answer, dict) or answer.get("source") == "unresolved":
        return None
    if isinstance(answer.get("label"), bool):
        return answer["label"]
    if answer.get("source") == "vega" and isinstance(answer.get("noul"), (int, float)):
        return answer["noul"] >= 0.5
    return None


def reached(answers):
    """False when Jev was needed for a question but never answered (busy, down or timed out), so
    the bookmark is asked again. An answer Jev gave but was unsure of stays as it is."""
    return not any(isinstance(a, dict) and a.get("source") == "unresolved" and a.get("fallback") is None
                   for qs in answers.values() for a in qs.values())


def targets(answers):
    """Tags and lists for one bookmark's answers ({classifier: {question: answer}})."""
    tags, lists = [], []
    for service, answer in sorted(answers.get("service-routing", {}).items()):
        if label(answer):
            tags.append(f"ai-svc:{service}")
            lists.append(SERVICE_LIST.format(service))
    kind = answers.get("bookmark-kind", {})
    for qid in ("method", "capability"):
        if label(kind.get(qid)):
            tags.append(f"ai-kind:{qid}")
    if label(kind.get("codyos")):
        lists.append(CODYOS_LIST)
    return tags, lists


def fetch_bookmarks(karakeep):
    bookmarks, cursor = [], None
    while True:
        query = {"limit": 100, "includeContent": "false"}
        if cursor:
            query["cursor"] = cursor
        page = karakeep.call("GET", "/api/v1/bookmarks", query=query)
        bookmarks += page["bookmarks"]
        cursor = page.get("nextCursor")
        if not cursor:
            return bookmarks


def embed(db, llama, model, states, batch=32):
    import numpy as np

    stale = []
    for bid, state in states.items():
        digest = hashlib.sha256(embed_text(state).encode()).hexdigest()
        row = db.execute("SELECT digest FROM vectors WHERE id = ?", (bid,)).fetchone()
        if not row or row[0] != digest:
            stale.append((bid, digest, embed_text(state)))
    for i in range(0, len(stale), batch):
        chunk = stale[i:i + batch]
        out = llama.call("POST", "/v1/embeddings", {"model": model, "input": [t for _, _, t in chunk]})
        for (bid, digest, _), item in zip(chunk, sorted(out["data"], key=lambda d: d["index"])):
            v = np.asarray(item["embedding"], dtype=np.float32)
            v /= np.linalg.norm(v) or 1.0
            db.execute("INSERT OR REPLACE INTO vectors VALUES (?, ?, ?)", (bid, digest, v.tobytes()))
        db.commit()
    logging.info("embedded %d new or changed bookmarks", len(stale))
    ids = [bid for bid in states]
    rows = dict(db.execute("SELECT id, vector FROM vectors").fetchall())
    return ids, np.stack([np.frombuffer(rows[bid], dtype=np.float32) for bid in ids])


def name_topic(llama, model, states):
    """A short topic name from the local chat model, given a cluster's most central bookmarks."""
    lines = "\n".join("- " + " | ".join(str(s.get(k, ""))[:limit] for k, limit in
                                        (("title", 100), ("summary", 160)) if s.get(k)) for s in states)
    out = llama.call("POST", "/v1/chat/completions", {
        "model": model, "temperature": 0, "max_tokens": 20,
        "chat_template_kwargs": {"enable_thinking": False},
        "messages": [{"role": "user", "content": "These saved bookmarks share one topic. Reply with only "
                      "a short lowercase topic name of 1 to 4 words.\n\n" + lines}]})
    name = out["choices"][0]["message"]["content"].strip().strip("\"'`.").lower()
    return " ".join(name.split())[:40] or None


def new_topics(db, llama, model, ids, vectors, states, saved_after):
    """Cluster bookmarks that fit no topic yet into new named topics."""
    import numpy as np
    from sklearn.cluster import KMeans

    k = max(2, round(math.sqrt(len(ids) / 2)))
    fit = KMeans(k, n_init=4, random_state=0).fit(vectors)
    centroids = fit.cluster_centers_ / np.linalg.norm(fit.cluster_centers_, axis=1, keepdims=True)
    made = 0
    for c, centroid in enumerate(centroids):
        members = np.where(fit.labels_ == c)[0]
        central = members[np.argsort(-(vectors[members] @ centroid))][:10]
        name = name_topic(llama, model, [states[ids[i]] for i in central])
        if name:
            db.execute("INSERT INTO topics (name, centroid, created, saved_after) VALUES (?, ?, ?, ?)",
                       (name, centroid.astype(np.float32).tobytes(), now(), saved_after))
            made += 1
    db.commit()
    logging.info("opened %d new topics from %d bookmarks", made, len(ids))


def topics(db, llama, model, ids, vectors, states, created, fits, reseed):
    """Each bookmark's nearest topic when it is similar enough. Topics stay fixed once named so
    their tags stay meaningful; bookmarks saved since topics were last opened that fit none
    open new topics once `reseed` gather."""
    import numpy as np

    def load():
        rows = db.execute("SELECT name, centroid FROM topics").fetchall()
        if not rows:
            return [], np.zeros((0, vectors.shape[1]), dtype=np.float32)
        return [r[0] for r in rows], np.stack([np.frombuffer(r[1], dtype=np.float32) for r in rows])

    names, centroids = load()
    best = (vectors @ centroids.T).max(1) if names else np.zeros(len(ids))
    (since,) = db.execute("SELECT max(saved_after) FROM topics").fetchone()
    loose = np.array([i for i in np.where(best < fits)[0] if not since or created[ids[i]] > since], dtype=int)
    if len(loose) >= reseed:
        # Later reseeds only consider bookmarks saved after the newest one clustered here.
        new_topics(db, llama, model, [ids[i] for i in loose], vectors[loose], states,
                   max(created[ids[i]] for i in loose))
        names, centroids = load()
    if not names:
        return {}
    similarity = vectors @ centroids.T
    nearest = similarity.argmax(1)
    return {bid: "ai-topic:" + names[n] for bid, n, s in zip(ids, nearest, similarity.max(1)) if s >= fits}


def duplicates(ids, vectors, created):
    """Each bookmark that nearly matches an older one."""
    similarity = vectors @ vectors.T
    found = set()
    for i, bid in enumerate(ids):
        for j in (similarity[i] >= DUPLICATE).nonzero()[0]:
            if j != i and created[ids[j]] < created[bid]:
                found.add(bid)
                break
    return found


def classify(laya, state):
    answers = {}
    for name in ("service-routing", "bookmark-kind"):
        out = laya.call("POST", "/v1/systemone", {"model": "laya", "classifier": name, "state": state})
        answers[name] = out["answers"]
    return answers


def record_answers(db, bid, answers):
    old = db.execute("SELECT answers FROM answers WHERE id = ?", (bid,)).fetchone()
    if old:
        before = json.loads(old[0])
        for name, qs in answers.items():
            for qid, answer in qs.items():
                was = label(before.get(name, {}).get(qid))
                if was is not None and label(answer) is not None and was != label(answer):
                    db.execute("INSERT INTO changes VALUES (?, ?, ?, ?, ?)",
                               (bid, now(), f"{name}.{qid}", json.dumps(was), json.dumps(label(answer))))
    db.execute("INSERT OR REPLACE INTO answers VALUES (?, ?, ?)", (bid, now(), json.dumps(answers)))


class Filer:
    """Add-only Karakeep writes, each remembered so it is made once."""

    def __init__(self, db, karakeep, dry_run):
        self.db, self.karakeep, self.dry_run = db, karakeep, dry_run
        self.lists = None

    def list_id(self, name):
        if self.lists is None:
            self.lists = {l["name"]: l["id"] for l in self.karakeep.call("GET", "/api/v1/lists")["lists"]}
        if name not in self.lists:
            icon = "🛠️" if name == CODYOS_LIST else "📂"
            self.lists[name] = self.karakeep.call("POST", "/api/v1/lists", {"name": name, "icon": icon})["id"]
        return self.lists[name]

    def file(self, bid, tags=(), lists=()):
        done = {t for (t,) in self.db.execute("SELECT target FROM filed WHERE id = ?", (bid,))}
        tags = [t for t in tags if t not in done]
        lists = [l for l in lists if "list:" + l not in done]
        if not (tags or lists):
            return
        if self.dry_run:
            print(json.dumps({"bookmark": bid, "tags": tags, "lists": lists}))
            return
        if tags:
            self.karakeep.call("POST", f"/api/v1/bookmarks/{bid}/tags",
                               {"tags": [{"tagName": t} for t in tags]})
        for name in lists:
            self.karakeep.call("PUT", f"/api/v1/lists/{self.list_id(name)}/bookmarks/{bid}")
        self.db.executemany("INSERT OR IGNORE INTO filed VALUES (?, ?, ?)",
                            [(bid, t, now()) for t in tags] + [(bid, "list:" + l, now()) for l in lists])
        self.db.commit()


def run(args, token):
    karakeep = Http(args.karakeep_url, token)
    llama = Http(args.llama_url, timeout=300)
    db_path = Path(args.state_dir) / "state.sqlite"
    with closing(connect(db_path)) as db:
        filer = Filer(db, karakeep, args.dry_run)
        bookmarks = fetch_bookmarks(karakeep)
        states = {b["id"]: s for b in bookmarks if (s := state_of(b))}
        created = {b["id"]: b.get("createdAt", "") for b in bookmarks}
        logging.info("%d bookmarks, %d ready to triage", len(bookmarks), len(states))

        # Pass 1: local grouping over the whole collection; --ids only limits what is filed.
        wanted = set(args.ids or states)
        if states:
            ids, vectors = embed(db, llama, args.embed_model, states)
            found = topics(db, llama, args.topic_model, ids, vectors, states, created,
                           args.topic_similarity, args.new_topic_after)
            for bid, topic in found.items():
                if bid in wanted and not db.execute(
                        "SELECT 1 FROM filed WHERE id = ? AND target LIKE 'ai-topic:%'", (bid,)).fetchone():
                    filer.file(bid, tags=[topic])
            for bid in duplicates(ids, vectors, created) & wanted:
                filer.file(bid, tags=["ai-duplicate"])

        # Pass 2: Laya, newest unclassified first, including bookmarks Jev never answered.
        if args.ids:
            queue = [bid for bid in args.ids if bid in states]
        else:
            seen = {bid for bid, answers in db.execute("SELECT id, answers FROM answers")
                    if reached(json.loads(answers))}
            queue = sorted((bid for bid in states if bid not in seen), key=created.get, reverse=True)
        office = datetime.now().weekday() < 5 and 8 <= datetime.now().hour < 17
        limit = args.office_limit if office and not args.ids else args.limit
        failures = 0
        for bid in queue[:limit]:
            try:
                answers = classify(llama, states[bid])
            except (urllib.error.URLError, OSError, KeyError, ValueError) as exc:
                failures += 1
                logging.warning("Laya could not classify %s: %s", bid, exc)
                if failures >= 3:
                    logging.error("stopping after 3 failed classifications")
                    break
                continue
            failures = 0
            if not args.dry_run:
                record_answers(db, bid, answers)
                db.commit()
            tags, lists = targets(answers)
            filer.file(bid, tags, lists)
        logging.info("classified up to %d of %d waiting bookmarks", min(limit, len(queue)), len(queue))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--state-dir", default=os.environ.get("STATE_DIRECTORY", "/var/lib/karakeep-triage"))
    parser.add_argument("--karakeep-url", default="http://127.0.0.1:3005")
    parser.add_argument("--llama-url", default="http://127.0.0.1:8081")
    parser.add_argument("--embed-model", default="qwen3-embedding-0.6b")
    parser.add_argument("--limit", type=int, default=400, help="bookmarks to classify per run")
    parser.add_argument("--office-limit", type=int, default=50,
                        help="bookmarks to classify per run on weekdays from 8 to 5")
    parser.add_argument("--topic-model", default="qwen-3.5-9b", help="local chat model that names topics")
    parser.add_argument("--topic-similarity", type=float, default=0.6,
                        help="cosine similarity a bookmark needs to its topic's centre")
    parser.add_argument("--new-topic-after", type=int, default=200,
                        help="bookmarks that fit no topic before new topics are opened")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the Karakeep writes instead of making them; Laya is still asked")
    parser.add_argument("--ids", nargs="+", help="classify only these bookmark IDs")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    credentials = os.environ.get("CREDENTIALS_DIRECTORY")
    token = (Path(credentials) / "karakeep-api-key").read_text().strip() if credentials else \
        os.environ.get("KARAKEEP_API_KEY")
    if not token:
        sys.exit("no Karakeep API key")
    Path(args.state_dir).mkdir(parents=True, exist_ok=True)
    run(args, token)


if __name__ == "__main__":
    main()
