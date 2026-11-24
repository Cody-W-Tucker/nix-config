import contextlib
from datetime import datetime
import importlib.util
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("laya_service", Path(__file__).with_name("laya-service.py"))
laya = importlib.util.module_from_spec(spec)
spec.loader.exec_module(laya)

Q = {"type": "choice", "instructions": "Did they accept?", "criteria": {"yes": "Accept", "no": "Decline"}}
N = {"type": "noul", "instructions": "Is it relevant?"}


def registry(**overrides):
    base = {"questions": {"first": Q, "second": Q}, "teacher": "jev-1.14", "learnFromTeacher": False,
            "minTeacherConfidence": 0.75, "minConfirmed": 2}
    return {"test": dict(base, **overrides), "another": dict(base)}


def rows(root):
    with closing(sqlite3.connect(root / "labels.sqlite")) as db:
        return [(json.loads(g), json.loads(s)) for g, s in
                db.execute("SELECT gold, sources FROM labels ORDER BY seq")]


class LayaTest(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.service = self.make(registry())
        self.request = {"state": "A fixture", "classifier": "test"}

    def make(self, reg):
        service = laya.DecisionService(self.root, reg, None, "jev-1.14", "key")
        service.vega = Mock(return_value={"answers": {
            "first": {"route": "auto", "choice": "yes"},
            "second": {"route": "review", "probabilities": {"yes": 0.6, "no": 0.4}},
        }})
        service.teacher = Mock(return_value={"second": {"type": "choice", "choice": "no", "confidence": 0.9}})
        return service

    def test_escalates_only_pending_question_and_does_not_learn_by_default(self):
        answers = self.service.decide(self.request)["answers"]
        self.service.teacher.assert_called_once_with("A fixture", {"second": Q}, "jev-1.14")
        self.assertEqual(answers["first"]["source"], "vega")
        self.assertEqual((answers["second"]["source"], answers["second"]["choice"]), ("fallback", "no"))
        self.assertEqual(answers["second"]["route"], "review")
        self.assertFalse((self.root / "labels.sqlite").exists())

    def test_registered_subset_and_inline_questions(self):
        reg = registry()
        self.assertEqual(laya.parse({"state": "s", "classifier": "test", "questions": ["second"]}, reg)[1],
                         {"second": Q})
        self.assertEqual(laya.parse({"state": "s", "questions": {"q": Q}}, reg), ("s", {"q": Q}, None))
        for bad in ({"state": "s", "classifier": "missing"},
                    {"state": "s", "classifier": "test", "questions": ["nope"]},
                    {"state": "s", "classifier": "test", "questions": {"first": Q}}):
            with self.assertRaises(ValueError):
                laya.parse(bad, reg)

    def test_ad_hoc_requests_use_the_default_teacher_and_never_learn(self):
        service = self.make(registry(learnFromTeacher=True))
        service.decide({"state": "A fixture", "questions": {"first": Q, "second": Q}})
        self.assertEqual(service.teacher.call_args.args[2], "jev-1.14")
        self.assertFalse((self.root / "labels.sqlite").exists())

    def test_local_only_classifier_never_calls_out(self):
        service = laya.DecisionService(self.root, registry(teacher=None), "https://example.invalid/x", None, "k")
        service.vega = self.service.vega
        with patch.object(laya.http.client, "HTTPSConnection") as conn:
            answers = service.decide(self.request)["answers"]
        conn.assert_not_called()
        self.assertEqual(answers["second"]["source"], "unresolved")

    def test_teacher_identifies_laya_to_opencode_go(self):
        service = laya.DecisionService(self.root, registry(),
                                       "https://opencode.ai/inference/go/systemone/v1/systemone", "jev-1.14", "k")
        answer = {"type": "choice", "choice": "no", "confidence": 0.9}
        with patch.object(laya.http.client, "HTTPSConnection") as connection:
            conn = connection.return_value
            conn.getresponse.return_value = Mock(status=200, read=Mock(return_value=laya.encode({"answers": {"first": answer}})))
            self.assertEqual(service.teacher("A fixture", {"first": Q}, "jev-1.14"), {"first": answer})
        method, path, body, headers = conn.request.call_args.args
        self.assertEqual((method, path), ("POST", "/inference/go/systemone/v1/systemone"))
        self.assertEqual(json.loads(body)["model"], "jev-1.14")
        self.assertEqual(headers["User-Agent"], "codyos-laya/1")
        self.assertEqual(headers["Authorization"], "Bearer k")

    def test_confident_fallback_labels_train_when_enabled(self):
        service = self.make(registry(learnFromTeacher=True))
        service.decide(self.request)
        self.assertEqual(rows(self.root), [({"second": "no"}, {"second": "teacher"})])

    def test_unconfident_invalid_and_unavailable_fallback_stay_unresolved(self):
        service = self.make(registry(learnFromTeacher=True))
        for raw in ({"second": {"choice": "no", "confidence": 0.5}},
                    {"second": {"choice": "unknown", "confidence": 0.99}}, {}):
            service.teacher.return_value = raw
            answers = service.decide(self.request)["answers"]
            self.assertEqual(answers["second"]["source"], "unresolved")
            self.assertTrue(answers["second"]["abstain"])
        service.teacher.side_effect = OSError("offline")
        self.assertEqual(service.decide(self.request)["answers"]["second"]["source"], "unresolved")
        self.assertFalse((self.root / "labels.sqlite").exists())

    def test_teacher_label_mapping(self):
        score = {"type": "score", "instructions": "How?", "criteria": ["low", "mid", "high"]}
        self.assertIs(laya.teacher_label({"noul": 0.9}, N, 0.75), True)
        self.assertIs(laya.teacher_label({"noul": 0.1}, N, 0.75), False)
        self.assertIsNone(laya.teacher_label({"noul": 0.6}, N, 0.75))
        self.assertEqual(laya.teacher_label({"score": 1.6, "confidence": 0.8,
                                             "probabilities": {"0": 0.1, "1": 0.2, "2": 0.7}}, score, 0.75), 2)
        self.assertIsNone(laya.teacher_label(None, Q, 0.75))

    def test_explicit_abstention_overrides_auto(self):
        self.service.vega.return_value["answers"]["first"]["abstain"] = True
        self.service.decide(self.request)
        self.service.teacher.assert_called_once_with("A fixture", {"first": Q, "second": Q}, "jev-1.14")

    def test_label_precedence_merges_per_question(self):
        reg = registry()
        laya.feedback(self.root, reg, [dict(self.request, gold={"first": "yes"})], "imported")
        with closing(laya.connect(self.root)) as db, db:
            laya.record(db, laya.dataset_key("test", reg), "A fixture", {"first": "no", "second": "no"}, "teacher")
        laya.feedback(self.root, reg, [dict(self.request, gold={"second": "yes"})])
        laya.feedback(self.root, reg, [dict(self.request, classifier="another", gold={"first": "no"})])
        self.assertEqual(rows(self.root), [
            ({"first": "yes", "second": "yes"}, {"first": "imported", "second": "human"}),
            ({"first": "no"}, {"first": "human"}),
        ])

    def test_invalid_feedback_is_never_written(self):
        for item in (dict(self.request, gold={"first": "invalid"}), dict(self.request, gold={}),
                     dict(self.request, classifier="missing", gold={"first": "yes"})):
            with self.assertRaises(ValueError):
                laya.feedback(self.root, registry(), [dict(self.request, gold={"first": "yes"}), item])
        self.assertFalse((self.root / "labels.sqlite").exists())

    def test_human_labels_are_held_out_for_calibration(self):
        stored = [(json.dumps("a"), json.dumps({"first": "yes", "second": "no"}),
                   json.dumps({"first": "teacher", "second": "human"}))]
        self.assertEqual(laya.split_rows(stored), ([{"state": "a", "gold": {"first": "yes"}}],
                                                   [{"state": "a", "gold": {"second": "no"}}]))

    def test_heads_are_cached_per_classifier(self):
        reg = registry()
        for name in ("test", "another"):
            (self.root / laya.dataset_key(name, reg) / "policy-1").mkdir(parents=True)
        agent = SimpleNamespace(vega=SimpleNamespace(heads={}), calibration=None)
        agent.predict = lambda state, qs: {"answers": {"first": {"route": "auto", "choice": agent.vega.heads["first"]}}}
        band = SimpleNamespace(questions={"first": {"reachable": True}})

        def load(path, model):
            model.heads["first"] = "yes" if laya.dataset_key("test", reg) in str(path) else "no"
            return SimpleNamespace(calibration=SimpleNamespace(band=band))

        loader = Mock(side_effect=load)
        service = laya.DecisionService(self.root, reg, None, None, "")
        with patch.dict(sys.modules, {"vegaml.policy": SimpleNamespace(load_policy=loader)}), \
                patch.object(laya, "new_agent", return_value=agent):
            seen = [service.vega("s", {"first": Q}, name)["answers"]["first"]["choice"]
                    for name in ("test", "another", "test", "another")]
        self.assertEqual(seen, ["yes", "no", "yes", "no"])
        self.assertEqual(loader.call_count, 2)

    def test_registered_classifier_without_published_version_defers_to_fallback(self):
        agent = SimpleNamespace(vega=SimpleNamespace(heads={}), calibration=None)
        agent.predict = lambda state, qs: {"answers": {"first": {"route": "auto", "choice": "yes"}}}
        service = laya.DecisionService(self.root, registry(), None, None, "")
        with patch.dict(sys.modules, {"vegaml.policy": SimpleNamespace(load_policy=Mock())}), \
                patch.object(laya, "new_agent", return_value=agent):
            registered = service.vega("s", {"first": Q}, "test")["answers"]["first"]
            ad_hoc = service.vega("s", {"first": Q}, None)["answers"]["first"]
        self.assertEqual(registered["route"], "review")
        self.assertEqual(ad_hoc["route"], "auto")

    def test_cpu_fallback_moves_to_the_gpu_when_it_frees_up(self):
        made = []

        def agent(device):
            made.append(device)
            a = SimpleNamespace(vega=SimpleNamespace(heads={}), calibration=None)
            a.predict = lambda state, qs: {"answers": {}}
            return a

        service = laya.DecisionService(self.root, registry(), None, None, "", device="cuda")
        with patch.dict(sys.modules, {"vegaml.policy": SimpleNamespace(load_policy=Mock())}), \
                patch.object(laya, "new_agent", side_effect=agent), \
                patch.object(laya, "training_device", side_effect=["cpu", "cuda"]), \
                patch.object(laya.time, "monotonic", side_effect=[1000.0, 1100.0, 1400.0]):
            for _ in range(3):
                service.vega("s", {"first": Q}, None)
        self.assertEqual(made, ["cpu", "cuda"])

    def test_gpu_needs_the_lease_and_is_given_back_when_it_ends(self):
        made, freed = [], Mock()

        def agent(device):
            made.append(device)
            a = SimpleNamespace(vega=SimpleNamespace(heads={}), calibration=None)
            a.predict = lambda state, qs: {"answers": {}}
            return a

        lease = Mock()
        lease.acquire.return_value = True
        service = laya.DecisionService(self.root, registry(), None, None, "", device="cuda", lease=lease)
        with patch.dict(sys.modules, {"vegaml.policy": SimpleNamespace(load_policy=Mock())}), \
                patch.object(laya, "new_agent", side_effect=agent), patch.object(laya, "free_gpu", freed), \
                patch.object(laya, "training_device", return_value="cuda"):
            service.vega("s", {"first": Q}, None)
            self.assertEqual(service.served_on, "cuda")
            lease.acquire.return_value = False  # evicted: the next read moves to the CPU
            service.vega("s", {"first": Q}, None)
        self.assertEqual(made, ["cuda", "cpu"])
        freed.assert_called_once()

    def test_lease_loads_the_placeholder_and_reads_running_models(self):
        seen = []

        class Fake(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                seen.append(self.path)
                body = json.dumps({"running": [{"model": "laya-gpu", "state": "ready"}]}).encode() \
                    if self.path == "/running" else b"ok"
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        with ThreadingHTTPServer(("127.0.0.1", 0), Fake) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            url = f"http://127.0.0.1:{server.server_port}"
            self.assertTrue(laya.Lease(url, "laya-gpu").acquire())
            self.assertTrue(laya.Lease(url, "laya-gpu").held())
            self.assertFalse(laya.Lease(url, "laya-train-gpu").held())
            server.shutdown()
        self.assertEqual(seen[0], "/upstream/laya-gpu/")
        self.assertFalse(laya.Lease("http://127.0.0.1:9", "x").acquire(timeout=2))
        self.assertTrue(laya.Lease().acquire())

    def trainer(self, reg):
        agent = Mock(vega=SimpleNamespace(heads={}, features=Mock(return_value=[1.0]),
                                          engine=SimpleNamespace(decide=Mock(return_value={}))), device="cpu")
        agent.fit.return_value = {"serving": ["first"]}
        agent.calibrate.return_value = {"band": {"first": 0.98}}

        def save(model, path, **kwargs):
            path.mkdir()

        return agent, [patch.dict(sys.modules, {"vegaml.policy": SimpleNamespace(save_policy=save)}),
                       patch.object(laya, "new_agent", return_value=agent),
                       patch.object(laya, "training_device", return_value="cpu"),
                       patch.object(laya, "MIN_ROWS", 3), patch.object(laya, "NEW_ROWS", 1)]

    def label(self, reg, state, value, source):
        laya.feedback(self.root, reg, [{"classifier": "test", "state": state, "gold": {"first": value}}], source)

    def test_trainer_waits_for_confirmed_labels_then_calibrates_on_them(self):
        reg = registry(questions={"first": Q})
        key = laya.dataset_key("test", reg)
        agent, patches = self.trainer(reg)
        evening = datetime(2026, 11, 24, 20)
        with contextlib.ExitStack() as stack:
            for p in patches:
                stack.enter_context(p)
            for state in ("One", "Two", "Three"):
                self.label(reg, state, "yes", "imported")
            laya.train(self.root, reg, self.root, now=evening)
            agent.fit.assert_not_called()
            self.label(reg, "Four", "no", "human")
            self.label(reg, "Five", "yes", "human")
            laya.train(self.root, reg, self.root, now=evening)
        self.assertEqual([p.name for p in laya.versions(self.root / key)], ["policy-5"])
        self.assertEqual(agent.fit.call_args.args[0], [{"state": s, "gold": {"first": "yes"}}
                                                       for s in ("One", "Two", "Three")])
        self.assertIs(agent.fit.call_args.kwargs["calibrate"], False)
        self.assertEqual(agent.calibrate.call_args.args[0],
                         [{"state": "Four", "gold": {"first": "no"}}, {"state": "Five", "gold": {"first": "yes"}}])

    def test_labels_that_arrive_while_waiting_for_calibration_count_toward_the_next_attempt(self):
        reg = registry(questions={"first": Q})
        agent, patches = self.trainer(reg)
        evening = datetime(2026, 11, 24, 20)
        with contextlib.ExitStack() as stack:
            for p in patches:
                stack.enter_context(p)
            stack.enter_context(patch.object(laya, "NEW_ROWS", 3))
            for state in ("One", "Two", "Three"):
                self.label(reg, state, "yes", "imported")
            laya.train(self.root, reg, self.root, now=evening)
            self.label(reg, "Four", "no", "human")
            self.label(reg, "Five", "yes", "human")
            laya.train(self.root, reg, self.root, now=evening)
        self.assertEqual(agent.fit.call_count, 1)

    def test_classifier_can_calibrate_on_imported_labels(self):
        reg = registry(questions={"first": Q}, calibrateOn=["imported"])
        agent, patches = self.trainer(reg)
        with contextlib.ExitStack() as stack:
            for p in patches:
                stack.enter_context(p)
            with closing(laya.connect(self.root)) as db, db:
                for state in ("One", "Two", "Three"):
                    laya.record(db, laya.dataset_key("test", reg), state, {"first": "yes"}, "teacher")
            self.label(reg, "Four", "no", "imported")
            self.label(reg, "Five", "yes", "imported")
            laya.train(self.root, reg, self.root, now=datetime(2026, 11, 24, 20))
        self.assertEqual([r["state"] for r in agent.fit.call_args.args[0]], ["One", "Two", "Three"])
        self.assertEqual([r["state"] for r in agent.calibrate.call_args.args[0]], ["Four", "Five"])

    def test_large_refits_wait_until_after_hours(self):
        reg = registry(questions={"first": Q})
        agent, patches = self.trainer(reg)
        tuesday_noon, tuesday_evening = datetime(2026, 11, 24, 12), datetime(2026, 11, 24, 18)
        with contextlib.ExitStack() as stack:
            for p in patches:
                stack.enter_context(p)
            for i, state in enumerate(("One", "Two", "Three", "Four", "Five")):
                self.label(reg, state, "yes", "human" if i > 2 else "imported")
            laya.train(self.root, reg, self.root, small=4, now=tuesday_noon)
            agent.fit.assert_not_called()
            laya.train(self.root, reg, self.root, small=4, now=tuesday_evening)
            self.assertEqual(agent.fit.call_count, 1)
            # Everything read once is cached, so the next refit is small enough for office hours.
            self.label(reg, "Six", "no", "imported")
            laya.train(self.root, reg, self.root, small=4, now=tuesday_noon)
            self.assertEqual(agent.fit.call_count, 2)

    def test_read_cache_reuses_reads_across_refits(self):
        reads = Mock(side_effect=lambda state, q: [len(state)])
        cache = laya.ReadCache(self.root / "reads.sqlite")
        first = cache.wrap("cpu:features", reads)
        self.assertEqual([first("ab", Q), first("ab", Q), first("abc", Q)], [[2], [2], [3]])
        cache.close()
        cache = laya.ReadCache(self.root / "reads.sqlite")
        self.addCleanup(cache.close)
        self.assertEqual(cache.wrap("cpu:features", reads)("ab", Q), [2])
        self.assertEqual(reads.call_count, 2)
        cache.wrap("cuda:features", reads)("ab", Q)
        self.assertEqual(reads.call_count, 3)

    def test_teacher_sends_systemone_request_with_key(self):
        seen = {}

        class Fake(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                seen["auth"] = self.headers["Authorization"]
                seen["body"] = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                data = json.dumps({"answers": {"second": {"type": "choice", "choice": "no", "confidence": 0.9}},
                                   "usage": {"input_tokens": 10}}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        with ThreadingHTTPServer(("127.0.0.1", 0), Fake) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            service = laya.DecisionService(self.root, registry(), f"http://127.0.0.1:{server.server_port}/systemone/v1/systemone", None, "secret")
            raw = service.teacher("state", {"second": Q}, "jev-1.14")
            server.shutdown()
        self.assertEqual(seen["auth"], "Bearer secret")
        self.assertEqual(seen["body"], {"model": "jev-1.14", "state": "state", "questions": {"second": Q}})
        self.assertEqual(raw["second"]["choice"], "no")
        with self.assertRaises(ValueError):
            laya.DecisionService(self.root, {}, "http://example.com/x", None, "")


if __name__ == "__main__":
    unittest.main()
