#!/usr/bin/env python3
"""Transcript history and learned vocabulary for the speech-to-text models.

The sherpa-onnx server posts every transcription here and returns the text
with vocabulary rules applied. Dictation attaches its normalized text, and a
correction of that text teaches new rules. Rules come from two places: the
declared vocabulary file in the repository and rules learned at runtime.
"""

import argparse
import base64
import difflib
import json
import logging
import re
import sqlite3
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

logger = logging.getLogger("speech-history")

# A correction longer than this on either side is a rewrite, not a vocabulary fix.
MAX_RULE_WORDS = 4

TOKEN = re.compile(r"[\w'’-]+|[^\w\s]")
WORD = re.compile(r"[\w'’-]+")

SCHEMA = """
create table if not exists transcriptions (
  id text primary key,
  created real not null,
  model text,
  client text,
  audio text,
  asr_text text not null,
  text text not null,
  normalized_text text,
  final_text text,
  corrected_text text
);
create table if not exists candidates (
  source text not null,
  target text not null,
  seen integer not null default 0,
  learned real,
  primary key (source, target)
);
"""


class Store:
    def __init__(self, state_dir: Path, vocabulary: Path | None, words: Path):
        self.state_dir = state_dir
        self.audio_dir = state_dir / "audio"
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self.vocabulary = vocabulary
        # SCOWL word lists are ISO-8859-1.
        self.common = {
            w.strip().lower() for w in words.read_text(encoding="latin-1").splitlines() if w.strip()
        }
        self.lock = threading.Lock()
        self.db = sqlite3.connect(state_dir / "history.sqlite", check_same_thread=False)
        self.db.execute("pragma journal_mode=wal")
        self.db.executescript(SCHEMA)

    # Rules -----------------------------------------------------------------

    def declared_rules(self) -> list[dict]:
        if self.vocabulary is None or not self.vocabulary.exists():
            return []
        return json.loads(self.vocabulary.read_text())

    def learned_rules(self) -> list[dict]:
        rows = self.db.execute(
            "select source, target from candidates where learned is not null order by learned"
        ).fetchall()
        return [{"from": s, "to": t} for s, t in rows]

    def rules(self) -> list[dict]:
        merged: dict[str, dict] = {}
        for rule in self.declared_rules() + self.learned_rules():
            merged[" ".join(rule["from"].split()).lower()] = {"from": rule["from"], "to": rule["to"]}
        return list(merged.values())

    def apply(self, text: str) -> str:
        rules = self.rules()
        if not rules or not text:
            return text
        by_source = {" ".join(r["from"].split()).lower(): r["to"] for r in rules}
        # Longest source first so "nix os" wins over "os"; one pass, so a
        # replacement is never rewritten by a later rule.
        sources = sorted(by_source, key=len, reverse=True)
        pattern = re.compile(
            "|".join(
                r"(?<![\w'’-])" + r"\s+".join(map(re.escape, s.split())) + r"(?![\w'’-])"
                for s in sources
            ),
            re.IGNORECASE,
        )
        return pattern.sub(lambda m: by_source[" ".join(m.group(0).split()).lower()], text)

    def learn(self, before: str, after: str) -> dict:
        """Record word-level corrections between two versions of a text."""
        a = [(m.group(0), m.start(), m.end()) for m in TOKEN.finditer(before)]
        b = [(m.group(0), m.start(), m.end()) for m in TOKEN.finditer(after)]
        matcher = difflib.SequenceMatcher(a=[t[0] for t in a], b=[t[0] for t in b], autojunk=False)
        learned, pending, ignored = [], [], []
        now = time.time()
        for op, i1, i2, j1, j2 in matcher.get_opcodes():
            if op != "replace":
                continue
            # Trim punctuation at the edges so "Hypoland," -> "Hyprland," teaches the word.
            while i1 < i2 and j1 < j2 and not WORD.fullmatch(a[i1][0]) and a[i1][0] == b[j1][0]:
                i1, j1 = i1 + 1, j1 + 1
            while i1 < i2 and j1 < j2 and not WORD.fullmatch(a[i2 - 1][0]) and a[i2 - 1][0] == b[j2 - 1][0]:
                i2, j2 = i2 - 1, j2 - 1
            source = " ".join(before[a[i1][1] : a[i2 - 1][2]].split())
            target = " ".join(after[b[j1][1] : b[j2 - 1][2]].split())
            source_words = WORD.findall(source)
            target_words = WORD.findall(target)
            if (
                not source_words
                or not target_words
                or len(source_words) > MAX_RULE_WORDS
                or len(target_words) > MAX_RULE_WORDS
            ):
                ignored.append({"from": source, "to": target})
                continue
            unusual = any(w.lower() not in self.common for w in source_words + target_words)
            with self.lock, self.db:
                self.db.execute(
                    "insert into candidates (source, target, seen) values (?, ?, 1) "
                    "on conflict (source, target) do update set seen = seen + 1",
                    (source, target),
                )
                (seen,) = self.db.execute(
                    "select seen from candidates where source = ? and target = ?", (source, target)
                ).fetchone()
                # A swap between common words ("their" -> "there") is right in one
                # sentence and wrong in the next, so it never applies everywhere on
                # its own; it waits in /suggestions for the declared vocabulary.
                if unusual:
                    self.db.execute(
                        "update candidates set learned = coalesce(learned, ?) where source = ? and target = ?",
                        (now, source, target),
                    )
                    # One source maps to one target: the newest correction wins.
                    self.db.execute(
                        "update candidates set learned = null where lower(source) = lower(?) and target != ?",
                        (source, target),
                    )
                    learned.append({"from": source, "to": target})
                else:
                    pending.append({"from": source, "to": target, "seen": seen})
        return {"learned": learned, "pending": pending, "ignored": ignored}

    def suggestions(self) -> list[dict]:
        rows = self.db.execute(
            "select source, target, seen from candidates where learned is null and seen > 0 "
            "order by seen desc, source"
        ).fetchall()
        return [{"from": s, "to": t, "seen": n} for s, t, n in rows]

    def forget(self, source: str) -> int:
        with self.lock, self.db:
            cur = self.db.execute(
                "update candidates set learned = null, seen = 0 where lower(source) = lower(?)", (source,)
            )
        return cur.rowcount

    # Transcriptions ----------------------------------------------------------

    def record(self, body: dict) -> dict:
        tid = uuid.uuid4().hex
        audio_name = None
        if body.get("audio"):
            ext = re.sub(r"[^a-z0-9]", "", (body.get("audio_ext") or "bin").lower())[:8] or "bin"
            audio_name = f"{tid}.{ext}"
            (self.audio_dir / audio_name).write_bytes(base64.b64decode(body["audio"]))
        asr_text = body.get("text", "")
        text = self.apply(asr_text)
        with self.lock, self.db:
            self.db.execute(
                "insert into transcriptions (id, created, model, client, audio, asr_text, text) "
                "values (?, ?, ?, ?, ?, ?, ?)",
                (tid, time.time(), body.get("model"), body.get("client"), audio_name, asr_text, text),
            )
        return {"id": tid, "text": text}

    def finish(self, tid: str, normalized: str) -> dict | None:
        final = self.apply(normalized)
        with self.lock, self.db:
            cur = self.db.execute(
                "update transcriptions set normalized_text = ?, final_text = ? where id = ?",
                (normalized, final, tid),
            )
        return {"id": tid, "text": final} if cur.rowcount else None

    def last(self) -> dict | None:
        row = self.db.execute(
            "select id, coalesce(corrected_text, final_text, text) from transcriptions "
            "where final_text is not null order by created desc limit 1"
        ).fetchone()
        return {"id": row[0], "text": row[1]} if row else None

    def correct(self, tid: str, corrected: str) -> dict | None:
        row = self.db.execute(
            "select coalesce(corrected_text, final_text, text) from transcriptions where id = ?", (tid,)
        ).fetchone()
        if row is None:
            return None
        result = self.learn(row[0], corrected)
        with self.lock, self.db:
            self.db.execute("update transcriptions set corrected_text = ? where id = ?", (corrected, tid))
        return result


def make_handler(store: Store):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            logger.info("%s %s", self.address_string(), fmt % args)

        def reply(self, status: int, body) -> None:
            data = json.dumps(body, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def body(self) -> dict:
            length = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(length) or b"{}")

        def do_GET(self):
            path = urlparse(self.path).path
            if path == "/health":
                self.reply(200, {"status": "ok"})
            elif path == "/vocabulary":
                self.reply(200, store.rules())
            elif path == "/suggestions":
                self.reply(200, store.suggestions())
            elif path == "/last":
                last = store.last()
                self.reply(200 if last else 404, last or {"error": "no dictation yet"})
            else:
                self.reply(404, {"error": "not found"})

        def do_POST(self):
            parts = urlparse(self.path).path.strip("/").split("/")
            try:
                body = self.body()
            except json.JSONDecodeError:
                self.reply(400, {"error": "invalid JSON"})
                return
            if parts == ["transcriptions"]:
                self.reply(200, store.record(body))
            elif parts == ["apply"]:
                self.reply(200, {"text": store.apply(body.get("text", ""))})
            elif len(parts) == 3 and parts[0] == "transcriptions" and parts[2] in ("final", "correction"):
                text = body.get("text")
                if not isinstance(text, str):
                    self.reply(400, {"error": "text is required"})
                    return
                fn = store.finish if parts[2] == "final" else store.correct
                result = fn(parts[1], text)
                self.reply(200 if result is not None else 404, result or {"error": "unknown id"})
            else:
                self.reply(404, {"error": "not found"})

        def do_DELETE(self):
            url = urlparse(self.path)
            source = parse_qs(url.query).get("from", [""])[0]
            if url.path == "/vocabulary" and source:
                self.reply(200, {"forgotten": store.forget(source)})
            else:
                self.reply(404, {"error": "not found"})

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--state-dir", type=Path, required=True)
    parser.add_argument("--vocabulary", type=Path)
    parser.add_argument("--common-words", type=Path, required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    store = Store(args.state_dir, args.vocabulary, args.common_words)
    ThreadingHTTPServer((args.host, args.port), make_handler(store)).serve_forever()


if __name__ == "__main__":
    main()
