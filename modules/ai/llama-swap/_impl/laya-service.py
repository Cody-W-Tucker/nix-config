"""The NAS SystemOne backend: Vega first, an OpenCode Go decision model for the rest.

Named classifiers come from the Nix-rendered registry. Their labels are stored per question
with a source (human > imported > teacher). Each classifier names the sources it calibrates on
(`calibrateOn`, human by default) and the share of states held out for it
(`calibrationShare`, all by default); the rest fit the heads.
"""

import argparse
from contextlib import closing, contextmanager
from datetime import datetime
import gc
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
import os
from pathlib import Path
import pickle
import re
import sqlite3
import sys
import tempfile
import threading
import time
import urllib.request
from urllib.parse import urlsplit


MAX_BODY = 128 * 1024
MAX_IMPORT = 64 * 1024 * 1024
MIN_ROWS = 300
NEW_ROWS = 50
SOURCES = {"teacher": 0, "imported": 1, "human": 2}
NAME = re.compile(r"[A-Za-z0-9_-]{1,64}")
USER_AGENT = "codyos-laya/1"


def encode(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False)


def digest(value):
    return hashlib.sha256(encode(value).encode()).hexdigest()


def options(q):
    kind = q.get("type")
    criteria = q.get("criteria")
    if kind == "choice" and isinstance(criteria, (dict, list)):
        labels = list(criteria)
        if len(labels) >= 2 and len(set(map(str, labels))) == len(labels) and all(
            isinstance(x, str) and 0 < len(x) <= 128 for x in labels
        ):
            return labels
    if kind == "noul":
        return [False, True]
    if kind == "score" and isinstance(criteria, list) and len(criteria) >= 2:
        return list(range(len(criteria)))
    raise ValueError("expected a choice, noul, or score question with valid options")


def is_label(value, q):
    return any(type(value) is type(x) and value == x for x in options(q))


def check_questions(questions):
    if not isinstance(questions, dict) or not 1 <= len(questions) <= 16:
        raise ValueError("expected 1 to 16 questions")
    for key, q in questions.items():
        if not NAME.fullmatch(key) or not isinstance(q, dict):
            raise ValueError("invalid question ID or question")
        if not isinstance(q.get("instructions"), str) or not q["instructions"].strip():
            raise ValueError("expected question instructions")
        if len(options(q)) > 24:
            raise ValueError("too many options")
    # Use identical option ordering for inference and training.
    return json.loads(encode(questions))


def load_registry(path):
    if path is None:
        return {}
    registry = json.loads(Path(path).read_text())
    for name, spec in registry.items():
        if not NAME.fullmatch(name):
            raise ValueError(f"invalid classifier name {name!r}")
        spec["questions"] = check_questions(spec["questions"])
    return registry


def check_state(state):
    if not isinstance(state, (str, dict, list)) or not state:
        raise ValueError("expected a nonempty text or JSON state")
    return json.loads(encode(state))


def parse(data, registry):
    """A request names a registered classifier (optionally a subset of its question IDs) or
    carries its own question definitions. Only registered classifiers learn."""
    if not isinstance(data, dict):
        raise ValueError("expected a request object")
    state = check_state(data.get("state"))
    name, asked = data.get("classifier"), data.get("questions")
    if name is None:
        return state, check_questions(asked), None
    if not isinstance(name, str) or name not in registry:
        raise ValueError("unknown classifier")
    questions = registry[name]["questions"]
    if asked is None:
        return state, questions, name
    if not isinstance(asked, list) or not asked or not set(asked) <= questions.keys():
        raise ValueError("registered classifiers take a list of their question IDs")
    return state, {k: questions[k] for k in asked}, name


def dataset_key(name, registry):
    return digest([name, registry[name]["questions"]])


def connect(root):
    db = sqlite3.connect(root / "labels.sqlite")
    db.execute("""CREATE TABLE IF NOT EXISTS labels (
        seq INTEGER PRIMARY KEY AUTOINCREMENT, dataset TEXT, input TEXT,
        state TEXT, gold TEXT, sources TEXT, UNIQUE(dataset, input))""")
    return db


def record(db, key, state, gold, source):
    """Merge labels into one row per input; a label never overwrites one from a better source."""
    old = db.execute("SELECT gold, sources FROM labels WHERE dataset = ? AND input = ?",
                     (key, digest(state))).fetchone()
    merged, sources = (json.loads(old[0]), json.loads(old[1])) if old else ({}, {})
    changed = False
    for qid, label in gold.items():
        if SOURCES[source] >= SOURCES.get(sources.get(qid), -1) and (
                merged.get(qid) != label or sources.get(qid) != source):
            merged[qid], sources[qid], changed = label, source, True
    if changed:
        db.execute("""INSERT OR REPLACE INTO labels (dataset, input, state, gold, sources)
            VALUES (?, ?, ?, ?, ?)""", (key, digest(state), encode(state), encode(merged), encode(sources)))
    return changed


def check_gold(gold, questions):
    if not isinstance(gold, dict) or not gold or not gold.keys() <= questions.keys() or not all(
        is_label(gold[k], questions[k]) for k in gold
    ):
        raise ValueError("gold must supply valid labels for some of the classifier's questions")
    return gold


def feedback(root, registry, items, source="human"):
    """Confirmed (`human`) or bulk-loaded (`imported`) labels for registered classifiers."""
    prepared = []
    for data in items:
        if not isinstance(data, dict) or data.get("classifier") not in registry:
            raise ValueError("feedback needs a registered classifier")
        name = data["classifier"]
        prepared.append((dataset_key(name, registry), check_state(data.get("state")),
                         check_gold(data.get("gold"), registry[name]["questions"])))
    with closing(connect(root)) as db, db:
        return sum(record(db, key, state, gold, source) for key, state, gold in prepared)


def versions(folder):
    return sorted((p for p in folder.glob("policy-*") if p.name[7:].isdigit()),
                  key=lambda p: int(p.name[7:]))


REVISION = "6aee375845724d2cca21d5fd5c043a028dbc1b48"
GPU_FREE_BYTES = int(2.5 * 1024 ** 3)
GPU_RETRY_SECONDS = 300


def new_agent(device="cpu"):
    from laya import VegaAgent

    return VegaAgent(vegaml="nandakishorm/vega-U", device=device, revision=REVISION)


def training_device():
    """CUDA when the card has room next to llama-swap's models, otherwise CPU."""
    try:
        import torch

        if torch.cuda.is_available():
            free, _ = torch.cuda.mem_get_info()
            if free >= GPU_FREE_BYTES:
                return "cuda"
            logging.info("GPU has %.1f GiB free; reading on CPU", free / 1024 ** 3)
    except Exception as exc:
        logging.info("GPU unavailable (%s); reading on CPU", exc)
    return "cpu"


def serving_device(requested):
    """Where Vega reads to serve: CUDA when asked for and the card has room, otherwise CPU."""
    return training_device() if requested == "cuda" else "cpu"


class Lease:
    """A GPU lease from llama-swap: a placeholder model whose declared VRAM stands for Vega's.

    Loading it makes llama-swap's capacity router evict cheaper models to make room; any
    request to it restarts its idle timer. Without a URL the GPU needs no lease."""

    def __init__(self, url=None, model=None):
        self.url = url.rstrip("/") if url else None
        self.model = model

    def acquire(self, timeout=60):
        if not self.url:
            return True
        try:
            with closing(urllib.request.urlopen(f"{self.url}/upstream/{self.model}/", timeout=timeout)) as r:
                return r.status == 200
        except OSError as exc:
            logging.info("no GPU lease from llama-swap: %s", exc)
            return False

    def held(self):
        if not self.url:
            return True
        try:
            with closing(urllib.request.urlopen(f"{self.url}/running", timeout=5)) as r:
                running = json.load(r).get("running", [])
        except (OSError, ValueError):
            return False
        return any(m.get("model") == self.model and m.get("state") == "ready" for m in running)

    @contextmanager
    def holding(self, every=120):
        """Keep the lease renewed for a long job; yields whether it was granted."""
        granted, done = self.acquire(), threading.Event()

        def renew():
            while not done.wait(every):
                self.acquire()

        if granted and self.url:
            threading.Thread(target=renew, daemon=True).start()
        try:
            yield granted
        finally:
            done.set()


def free_gpu():
    gc.collect()
    try:
        import torch

        torch.cuda.empty_cache()
    except Exception:
        pass


def business_hours(now):
    return now.weekday() < 5 and 8 <= now.hour < 17


class ReadCache:
    """Vega's reads of a (state, question) during training, kept across refits.

    Reads are keyed by the model revision and device type: CUDA reads in bfloat16 and the CPU
    in float32, so the two are never mixed. `seen` records which labels a refit has read."""

    def __init__(self, path):
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute("CREATE TABLE IF NOT EXISTS reads (key TEXT PRIMARY KEY, value BLOB)")
        self.db.execute("""CREATE TABLE IF NOT EXISTS seen (dataset TEXT, input TEXT, question TEXT,
            PRIMARY KEY (dataset, input, question))""")

    def close(self):
        self.db.close()

    def wrap(self, kind, fn):
        def cached(*args, **kw):
            key = hashlib.sha256(json.dumps([REVISION, kind, args, kw], sort_keys=True,
                                            default=repr).encode()).hexdigest()
            row = self.db.execute("SELECT value FROM reads WHERE key = ?", (key,)).fetchone()
            if row:
                return pickle.loads(row[0])
            value = fn(*args, **kw)
            self.db.execute("INSERT OR REPLACE INTO reads VALUES (?, ?)", (key, pickle.dumps(value)))
            return value
        return cached

    def attach(self, agent):
        kind = getattr(agent.device, "type", str(agent.device))
        agent.vega.features = self.wrap(f"{kind}:features", agent.vega.features)
        agent.vega.engine.decide = self.wrap(f"{kind}:engine", agent.vega.engine.decide)
        return agent

    def pending(self, key, pairs):
        return sum(self.db.execute("SELECT 1 FROM seen WHERE dataset = ? AND input = ? AND question = ?",
                                   (key, i, q)).fetchone() is None for i, q in pairs)

    def mark(self, key, pairs):
        self.db.executemany("INSERT OR IGNORE INTO seen VALUES (?, ?, ?)", [(key, i, q) for i, q in pairs])


def held_out(state_text, share):
    """True for a fixed `share` of states, so a state stays on the same side across refits."""
    return share >= 1 or int(hashlib.sha256(state_text.encode()).hexdigest()[:8], 16) < share * 2 ** 32


def split_rows(rows, calibrate_on=("human",), share=1.0):
    """In the held-out share of states, labels from the calibration sources calibrate; every
    other label fits the heads."""
    fit, calibrate = [], []
    for state_text, gold, sources in rows:
        state, gold, sources = json.loads(state_text), json.loads(gold), json.loads(sources)
        hold = held_out(state_text, share)
        held = {k: v for k, v in gold.items() if hold and sources.get(k) in calibrate_on}
        other = {k: v for k, v in gold.items() if k not in held}
        if other:
            fit.append({"state": state, "gold": other})
        if held:
            calibrate.append({"state": state, "gold": held})
    return fit, calibrate


def train(root, registry, cache_dir, small=200, now=None, device="cpu", lease=None):
    """Refit classifiers with enough new labels. During business hours, only refits needing at
    most `small` uncached reads run; larger ones wait for an evening or weekend run."""
    if not (root / "labels.sqlite").exists():
        return
    office = business_hours(now or datetime.now())
    cache = ReadCache(cache_dir / "vega-reads.sqlite")
    agents = {}

    def agent(device):
        if device not in agents:
            agents[device] = cache.attach(new_agent(device))
        return agents[device]

    try:
        with closing(connect(root)) as db:
            for name, spec in registry.items():
                key = dataset_key(name, registry)
                rows = db.execute("""SELECT seq, input, state, gold, sources FROM labels WHERE dataset = ?
                                   ORDER BY seq DESC LIMIT 5000""", (key,)).fetchall()
                if len(rows) < MIN_ROWS:
                    continue
                latest = rows[0][0]
                folder = root / key
                folder.mkdir(mode=0o700, exist_ok=True)
                marker = folder / "last-attempt"
                previous = int(marker.read_text()) if marker.exists() else 0
                if sum(r[0] > previous for r in rows) < NEW_ROWS:
                    continue
                calibrate_on = spec.get("calibrateOn", ["human"])
                fit, calibrate = split_rows(reversed([r[2:] for r in rows]), calibrate_on,
                                            spec.get("calibrationShare", 1.0))
                pairs = [(r[1], q) for r in rows for q in json.loads(r[3])]
                if len(calibrate) < spec["minConfirmed"]:
                    # Not an attempt: the labels that arrived meanwhile still count toward the next one.
                    logging.info("Laya classifier %s has %d of %d %s labels needed to calibrate",
                                 name, len(calibrate), spec["minConfirmed"], "/".join(calibrate_on))
                    continue
                if not fit:
                    logging.info("Laya classifier %s has no labels outside %s to fit on",
                                 name, "/".join(calibrate_on))
                    continue
                pending = cache.pending(key, pairs)
                if office and pending > small:
                    logging.info("Laya classifier %s needs %d new reads; waiting until after hours",
                                 name, pending)
                    continue
                logging.info("refitting Laya classifier %s with %d new reads", name, pending)
                try:
                    with (lease or Lease()).holding() as leased:
                        fit_policy(agent, fit, calibrate, spec["questions"], folder / f"policy-{latest}",
                                   device if leased else "cpu")
                except ValueError as exc:
                    logging.warning("could not fit Laya classifier %s at version %d: %s", name, latest, exc)
                cache.mark(key, pairs)
                draft = marker.with_suffix(".next")
                draft.write_text(str(latest))
                draft.replace(marker)
    finally:
        cache.close()


def fit_policy(agent, fit, calibrate, questions, target, device="cpu"):
    """Heads from the bulk labels (on the GPU when it has room), then the calibration on the
    held-out labels on the serving device, so the band measures what serves."""
    from vegaml.policy import save_policy

    if target.exists():
        return
    reader = agent(serving_device(device))
    reader.vega.heads.clear()
    reader.calibration = None
    report = reader.fit(fit, questions=questions, calibrate=False)
    serving = agent(serving_device(device))
    serving.vega.heads.clear()
    serving.vega.heads.update(reader.vega.heads)
    report = dict(report, calibration=serving.calibrate(calibrate, questions))
    band = report["calibration"]["band"] or {}
    held = getattr(serving.calibration, "report", None)
    for qid, q in sorted((k, v["band"]) for k, v in (held.items() if isinstance(held, dict) else ())
                         if isinstance(v, dict) and isinstance(v.get("band"), dict)):
        best = q.get("best_achievable") or {}
        logging.info("Laya classifier %s question %s: %s on %s held-out labels%s", target.parent.name[:12], qid,
                     "certified" if q.get("reachable", True) else "not certified", q.get("n"),
                     "" if q.get("reachable", True) else ", best %.3f precision at %.0f%% sent to Jev" % (
                         best.get("precision_lb", 0.0), 100 * best.get("review_rate", 1.0)))
    if not any(band.get(qid) is not None for qid in report["serving"]):
        logging.info("Laya classifier %s reached no certified band", target.parent.name[:12])
        return
    with tempfile.TemporaryDirectory(dir=target.parent) as tmp:
        draft = Path(tmp) / "policy"
        save_policy(serving.vega, draft, calibration=serving.calibration, questions=questions)
        draft.rename(target)
    logging.info("published Laya classifier %s at %s", target.parent.name[:12], target.name)


def teacher_label(answer, q, threshold):
    """A decision model's answer as a label, or None when it is not confident enough."""
    kind = q["type"]
    if not isinstance(answer, dict):
        return None
    if kind == "noul":
        p = answer.get("noul")
        if not isinstance(p, (int, float)):
            return None
        return True if p >= threshold else False if p <= 1 - threshold else None
    confidence = answer.get("confidence")
    if not isinstance(confidence, (int, float)) or confidence < threshold:
        return None
    if kind == "choice":
        label = answer.get("choice")
    else:
        probabilities = answer.get("probabilities")
        if not isinstance(probabilities, dict) or not probabilities:
            return None
        best = max(probabilities, key=probabilities.get)
        label = int(best) if str(best).isdigit() else None
    return label if is_label(label, q) else None


class DecisionService:
    def __init__(self, root, registry, teacher_url, default_teacher, api_key, device="cpu", lease=None):
        self.root = root
        self.device = device
        self.lease = lease or Lease()
        self.registry = registry
        self.teacher_url = urlsplit(teacher_url) if teacher_url else None
        if self.teacher_url and not (self.teacher_url.scheme == "https" or (
                self.teacher_url.scheme == "http" and self.teacher_url.hostname == "127.0.0.1")):
            raise ValueError("fallback must use HTTPS")
        self.default_teacher = default_teacher
        self.api_key = api_key
        self.lock = threading.Lock()
        self.write_lock = threading.Lock()
        self.teacher_slots = threading.BoundedSemaphore(4)
        self.agent = None
        self.served_on, self.checked = None, 0.0
        self.policies = {}  # classifier -> (policy path, heads, calibration)

    def heads(self, agent, name):
        from vegaml.policy import load_policy

        if name is None:
            return {}, None
        candidates = versions(self.root / dataset_key(name, self.registry))
        latest = candidates[-1] if candidates else None
        cached = self.policies.get(name)
        if cached and cached[0] == latest:
            return cached[1], cached[2]
        heads, calibration = {}, None
        if latest:
            try:
                agent.vega.heads.clear()
                calibration = load_policy(latest, model=agent.vega).calibration
                heads = dict(agent.vega.heads)
            except Exception:
                heads, calibration = {}, None
                logging.error("unable to load Laya policy for %s", name)
        self.policies[name] = (latest, heads, calibration)
        return heads, calibration

    def place(self):
        """The device for the next read. The GPU needs a renewed lease and room on the card;
        a CPU fallback retries the GPU every few minutes."""
        if self.device != "cuda":
            return "cpu"
        now = time.monotonic()
        if self.served_on == "cpu" and now - self.checked < GPU_RETRY_SECONDS:
            return "cpu"
        if not self.lease.acquire():
            self.checked = now
            return "cpu"
        if self.served_on == "cuda":
            return "cuda"
        self.checked = now
        return training_device()

    def leave_gpu(self):
        if self.served_on == "cuda":
            self.agent, self.served_on, self.policies = None, None, {}
            free_gpu()

    def watch_lease(self, every=15):
        """Give the GPU back once llama-swap evicts the lease or it expires while idle."""
        def loop():
            while True:
                time.sleep(every)
                if self.served_on == "cuda" and not self.lease.held():
                    with self.lock:
                        if self.served_on == "cuda" and not self.lease.held():
                            logging.info("GPU lease ended; Vega leaves the GPU")
                            self.leave_gpu()

        threading.Thread(target=loop, daemon=True).start()

    def vega(self, state, questions, name):
        with self.lock:
            device = self.place()
            if self.agent is None or device != self.served_on:
                self.leave_gpu()
                logging.info("Vega serves on %s", device)
                self.agent, self.served_on, self.policies = new_agent(device), device, {}
            agent = self.agent
            heads, calibration = self.heads(agent, name)
            agent.vega.heads.clear()
            agent.vega.heads.update(heads)
            agent.calibration = calibration
            out = agent.predict(state, questions)
            # A registered classifier answers alone only from a published, calibrated version;
            # until then the base model's zero-shot reads go to the fallback.
            if name is not None:
                band = getattr(calibration, "band", None) if heads else None
                for qid, answer in out["answers"].items():
                    if not band or not band.questions.get(qid, {}).get("reachable", False):
                        answer.update(route="review", route_reason="no certified precision band")
            return out

    def teacher(self, state, questions, model):
        """Raw answers from an OpenCode Go decision model. No tools, actions or other hosts."""
        if not self.teacher_url or not model or not self.teacher_slots.acquire(blocking=False):
            return {}
        url = self.teacher_url
        try:
            kind = http.client.HTTPSConnection if url.scheme == "https" else http.client.HTTPConnection
            with closing(kind(url.hostname, url.port, timeout=30)) as conn:
                conn.request("POST", url.path, encode({"model": model, "state": state, "questions": questions}).encode(),
                             {"Content-Type": "application/json", "User-Agent": USER_AGENT,
                              "Authorization": f"Bearer {self.api_key}"})
                response = conn.getresponse()
                if response.status != 200:
                    raise ValueError(f"fallback returned HTTP {response.status}")
                body = json.loads(response.read(MAX_BODY))
        finally:
            self.teacher_slots.release()
        answers = body.get("answers") if isinstance(body, dict) else None
        if not isinstance(answers, dict):
            raise ValueError("invalid fallback result")
        return {qid: answers.get(qid) for qid in questions}

    def decide(self, data):
        state, questions, name = parse(data, self.registry)
        spec = self.registry.get(name, {})
        try:
            out = self.vega(state, questions, name)
        except Exception:
            logging.error("Vega prediction failed")
            out = {"answers": {}}
        answers = out["answers"]
        pending = {}
        for qid, q in questions.items():
            answer = answers.get(qid, {})
            if answer.get("route") == "auto" and answer.get("abstain") is not True:
                answer["source"] = "vega"
            else:
                pending[qid] = q
        raw = {}
        if pending:
            try:
                raw = self.teacher(state, pending, spec.get("teacher", self.default_teacher))
            except Exception as exc:
                logging.warning("Laya fallback unavailable: %s", exc)
        learned = {}
        for qid, q in pending.items():
            label = teacher_label(raw.get(qid), q, spec.get("minTeacherConfidence", 0.75))
            resolved = label is not None
            answers[qid] = {"type": q["type"], "route": "review", "abstain": not resolved,
                            "source": "fallback" if resolved else "unresolved",
                            "label": label, "fallback": raw.get(qid), "vega": answers.get(qid)}
            if resolved:
                if q["type"] in ("choice", "score"):
                    answers[qid][q["type"]] = label
                learned[qid] = label
        if learned and spec.get("learnFromTeacher"):
            try:
                with self.write_lock, closing(connect(self.root)) as db, db:
                    record(db, dataset_key(name, self.registry), state, learned, "teacher")
            except sqlite3.Error:
                logging.error("could not store fallback labels for %s", name)
        return out


class Handler(BaseHTTPRequestHandler):
    timeout = 15

    def log_message(self, *_):
        pass  # No input or caller-supplied paths in logs.

    def reply(self, status, body):
        data = encode(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.reply(200, {"status": "ok"}) if self.path == "/health" else self.reply(404, {})

    def do_POST(self):
        if self.path != "/v1/systemone":
            self.reply(404, {})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= MAX_BODY:
                self.reply(413, {"error": "invalid body size"})
                return
            if not self.server.slots.acquire(blocking=False):
                self.reply(503, {"error": "Laya is busy"})
                return
            try:
                body = self.server.service.decide(json.loads(self.rfile.read(length)))
            finally:
                self.server.slots.release()
        except (ValueError, RecursionError) as exc:
            self.reply(400, {"error": f"invalid SystemOne request: {exc}"})
            return
        self.reply(200, body)


def read_items(data):
    """One JSON object, or JSON Lines for bulk imports."""
    try:
        item = json.loads(data)
        return [item]
    except json.JSONDecodeError:
        return [json.loads(line) for line in data.splitlines() if line.strip()]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["serve", "feedback", "train"])
    parser.add_argument("--state-dir", type=Path, default=Path("/var/lib/laya"))
    parser.add_argument("--classifiers", type=Path, default=os.environ.get("LAYA_CLASSIFIERS"))
    parser.add_argument("--port", type=int, default=18091)
    parser.add_argument("--teacher-url")
    parser.add_argument("--default-teacher")
    parser.add_argument("--source", choices=["human", "imported"], default="human")
    parser.add_argument("--cache-dir", type=Path, default=Path("/var/cache/laya"))
    parser.add_argument("--small-refit", type=int, default=200,
                        help="most uncached reads a refit may need during business hours")
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cpu",
                        help="where Vega serves and is calibrated; cuda falls back to cpu when the card is full")
    parser.add_argument("--lease-url", help="llama-swap that grants GPU leases")
    parser.add_argument("--lease-model", help="llama-swap placeholder model that holds the lease")
    args = parser.parse_args()
    lease = Lease(args.lease_url, args.lease_model)
    os.umask(0o077)
    logging.basicConfig(level=logging.INFO)
    registry = load_registry(args.classifiers)
    if args.mode == "feedback":
        data = sys.stdin.buffer.read(MAX_IMPORT + 1)
        if len(data) > MAX_IMPORT:
            parser.error("feedback is too large")
        try:
            changed = feedback(args.state_dir, registry, read_items(data), args.source)
        except (ValueError, json.JSONDecodeError) as exc:
            parser.error(str(exc))
        print(f"Saved {changed} {args.source} example(s).")
    elif args.mode == "train":
        train(args.state_dir, registry, args.cache_dir, args.small_refit, device=args.device, lease=lease)
    else:
        with closing(connect(args.state_dir)) as db, db:
            pass  # The nightly backup expects the label store to exist.
        with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
            server.service = DecisionService(args.state_dir, registry, args.teacher_url,
                                             args.default_teacher, os.environ.get("OPENCODE_GO_API_KEY", ""),
                                             args.device, lease)
            server.service.watch_lease()
            server.slots = threading.BoundedSemaphore(4)
            server.serve_forever()


if __name__ == "__main__":
    main()
