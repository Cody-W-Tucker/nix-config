"""File Karakeep bookmarks into lists with Laya's classifiers.

Laya's `bookmark-route` classifier picks each bookmark's one destination, and the bookmark is
filed to that `Agency: <service>` list or the `CodyOS: candidates` list.

Karakeep writes only ever add. A later different answer is logged in the state database,
never removed from Karakeep.

A bookmark no one was sure of (Jev answered, but not confidently) gets `ai-route:unsure`.

The service and CodyOS lists are the user's to curate. A bookmark they added to or took out of
any list goes to Laya as their label: the one list it is now in, or `none` if it is in none.
A bookmark in several lists has no single route and teaches nothing until one is left. The
user's labelled bookmarks are not asked again; entries triage made and the user left alone
teach nothing.
"""

import argparse
from collections import Counter
from contextlib import closing
from datetime import datetime, timezone
import json
import logging
import http.client
import os
from pathlib import Path
import socket
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SERVICE_LIST = "Agency: {}"
CODYOS_LIST = "CodyOS: candidates"
ROUTE = "bookmark-route"
CODYOS, NONE = "codyos", "none"
UNSURE = "ai-route:unsure"
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
        CREATE TABLE IF NOT EXISTS answers (id TEXT PRIMARY KEY, at TEXT, answers TEXT);
        CREATE TABLE IF NOT EXISTS filed (id TEXT, target TEXT, at TEXT, PRIMARY KEY (id, target));
        CREATE TABLE IF NOT EXISTS changes (id TEXT, at TEXT, question TEXT, old TEXT, new TEXT);
        CREATE TABLE IF NOT EXISTS curated (id TEXT, list TEXT, label INTEGER, at TEXT,
                                            PRIMARY KEY (id, list));
        CREATE TABLE IF NOT EXISTS routed (id TEXT PRIMARY KEY, route TEXT, at TEXT);
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


def label(answer):
    """The route from a Laya answer, or None when neither Vega nor the fallback was sure."""
    if not isinstance(answer, dict) or answer.get("source") == "unresolved":
        return None
    if isinstance(answer.get("label"), str):
        return answer["label"]
    if answer.get("source") == "vega" and isinstance(answer.get("choice"), str):
        return answer["choice"]
    return None


def who(answer):
    """Who settled a route answer: vega, jev, unsure (Jev answered without confidence) or
    unreached (Jev was needed but busy, down or timed out)."""
    source = answer.get("source") if isinstance(answer, dict) else None
    if source == "vega":
        return "vega"
    if source == "fallback":
        return "jev"
    return "unreached" if not isinstance(answer, dict) or answer.get("fallback") is None else "unsure"


def reached(answers):
    """False when Jev was needed for a question but never answered (busy, down or timed out), so
    the bookmark is asked again. An answer Jev gave but was unsure of stays as it is."""
    return not any(isinstance(a, dict) and a.get("source") == "unresolved" and a.get("fallback") is None
                   for qs in answers.values() for a in qs.values())


def targets(answers):
    """Tags and lists for one bookmark's answers ({classifier: {question: answer}})."""
    answer = answers.get(ROUTE, {}).get("route")
    if who(answer) == "unsure":
        return [UNSURE], []
    route = label(answer)
    if route == CODYOS:
        return [], [CODYOS_LIST]
    if isinstance(route, str) and route != NONE:
        return [], [SERVICE_LIST.format(route)]
    return [], []


def route_lists(services):
    """Each list the user curates, and the route its membership stands for."""
    lists = {SERVICE_LIST.format(s): s for s in services}
    lists[CODYOS_LIST] = CODYOS
    return lists


def routes_from_lists(members, touched, sent):
    """The user's labels to send: {bookmark: route}, the one list each touched bookmark is in, or
    `none` when it is in none. Bookmarks in several lists, and unchanged labels, are skipped."""
    out = {}
    for bid in touched:
        routes = members.get(bid, set())
        if len(routes) > 1:
            continue
        route = next(iter(routes), NONE)
        if sent.get(bid) != route:
            out[bid] = route
    return out


def fetch_bookmarks(karakeep, path="/api/v1/bookmarks"):
    bookmarks, cursor = [], None
    while True:
        query = {"limit": 100, "includeContent": "false"}
        if cursor:
            query["cursor"] = cursor
        page = karakeep.call("GET", path, query=query)
        bookmarks += page["bookmarks"]
        cursor = page.get("nextCursor")
        if not cursor:
            return bookmarks


class UnixConnection(http.client.HTTPConnection):
    def __init__(self, path, timeout=60):
        super().__init__("localhost", timeout=timeout)
        self.socket_path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.socket_path)


def send_labels(path, items):
    """Human labels to Laya's feedback socket; returns how many it saved."""
    conn = UnixConnection(path)
    try:
        conn.request("POST", "/v1/feedback", json.dumps({"items": items}), {"Content-Type": "application/json"})
        response = conn.getresponse()
        body = response.read()
        if response.status != 200:
            raise ValueError(f"Laya refused the labels: HTTP {response.status} {body[:200]!r}")
        return json.loads(body)["saved"]
    finally:
        conn.close()


def curate(db, filer, karakeep, lists, states, laya_socket, dry_run):
    """Send the lists' routes to Laya as labels (see the module docstring)."""
    members, touched, marks = {}, set(), []
    for name, route in lists.items():
        if name not in filer.known():
            continue
        inside = {b["id"] for b in fetch_bookmarks(karakeep, f"/api/v1/lists/{filer.list_id(name)}/bookmarks")}
        filed = {bid for (bid,) in db.execute("SELECT id FROM filed WHERE target = ?", ("list:" + name,))}
        for bid in inside:
            members.setdefault(bid, set()).add(route)
        # Added by the user, or an entry triage made that they took out.
        edited = (inside - filed) | (filed - inside)
        touched |= edited
        marks += [(bid, name, int(bid in inside), now()) for bid in edited]
    # Bookmarks the user edited on an earlier run stay theirs.
    touched |= {bid for (bid,) in db.execute("SELECT DISTINCT id FROM curated")}
    sent = dict(db.execute("SELECT id, route FROM routed"))
    # Deleted bookmarks are not labels; ones still awaiting a summary wait for it.
    labels = routes_from_lists(members, touched & states.keys(), sent)
    if not labels:
        return set()
    if dry_run:
        for bid, route in sorted(labels.items()):
            print(json.dumps({"bookmark": bid, "label": route}))
        return set(labels)
    if not laya_socket:
        logging.warning("%d list edits not sent: no Laya feedback socket", len(labels))
        return set()
    items = [{"classifier": ROUTE, "state": states[bid], "gold": {"route": route}} for bid, route in labels.items()]
    try:
        saved = send_labels(laya_socket, items)
    except (OSError, ValueError, KeyError) as exc:
        logging.warning("list edits not sent to Laya; retrying next run: %s", exc)
        return set()
    db.executemany("INSERT OR REPLACE INTO routed VALUES (?, ?, ?)", [(b, r, now()) for b, r in labels.items()])
    db.executemany("INSERT OR REPLACE INTO curated VALUES (?, ?, ?, ?)", marks)
    db.commit()
    logging.info("sent %d list edits to Laya as your labels (%d changed)", len(labels), saved)
    return set(labels)


def classify(laya, state):
    out = laya.call("POST", "/v1/systemone", {"model": "laya", "classifier": ROUTE, "state": state})
    return {ROUTE: out["answers"]}


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

    def known(self):
        if self.lists is None:
            self.lists = {l["name"]: l["id"] for l in self.karakeep.call("GET", "/api/v1/lists")["lists"]}
        return self.lists

    def ensure(self, names):
        """Every list triage files into exists, so the user can curate it before anything lands."""
        missing = [n for n in names if n not in self.known()]
        if self.dry_run:
            for name in missing:
                print(json.dumps({"create list": name}))
            return
        for name in missing:
            self.list_id(name)
        if missing:
            logging.info("created lists: %s", ", ".join(missing))

    def list_id(self, name):
        if name not in self.known():
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

        # The lists become Laya's labels.
        lists = route_lists(args.services)
        filer.ensure(lists)
        labelled = curate(db, filer, karakeep, lists, states, args.laya_feedback, args.dry_run)

        # Laya, newest unrouted first, including bookmarks Jev never answered. Bookmarks
        # the user has labelled are not asked.
        if args.ids:
            queue = [bid for bid in args.ids if bid in states]
        else:
            seen = {bid for bid, answers in db.execute("SELECT id, answers FROM answers")
                    if ROUTE in (a := json.loads(answers)) and reached(a)}
            seen |= labelled | {bid for (bid,) in db.execute("SELECT id FROM routed")}
            queue = sorted((bid for bid in states if bid not in seen), key=created.get, reverse=True)
        office = datetime.now().weekday() < 5 and 8 <= datetime.now().hour < 17
        limit = args.office_limit if office and not args.ids else args.limit
        failures, tally = 0, Counter()
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
            tally[who(answers[ROUTE].get("route"))] += 1
            if not args.dry_run:
                record_answers(db, bid, answers)
                db.commit()
            tags, lists = targets(answers)
            filer.file(bid, tags, lists)
        logging.info("routed %d of %d waiting bookmarks: vega %d, jev %d, unsure %d, unreached %d",
                     sum(tally.values()), len(queue), *(tally[k] for k in ("vega", "jev", "unsure", "unreached")))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--state-dir", default=os.environ.get("STATE_DIRECTORY", "/var/lib/karakeep-triage"))
    parser.add_argument("--karakeep-url", default="http://127.0.0.1:3005")
    parser.add_argument("--llama-url", default="http://127.0.0.1:8081")
    parser.add_argument("--limit", type=int, default=400, help="bookmarks to classify per run")
    parser.add_argument("--office-limit", type=int, default=50,
                        help="bookmarks to classify per run on weekdays from 8 to 5")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the Karakeep writes instead of making them; Laya is still asked")
    parser.add_argument("--ids", nargs="+", help="classify only these bookmark IDs")
    parser.add_argument("--services", nargs="*", default=[],
                        help="service-routing question IDs; each gets an `Agency: <id>` list")
    parser.add_argument("--laya-feedback", help="Laya's feedback socket for the user's list edits")
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
