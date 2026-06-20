#!/usr/bin/env python3
import asyncio
import base64
import fcntl
import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import websockets


BASE_URL = os.environ.get("HERMES_BASE_URL", "http://127.0.0.1:8642").rstrip("/")
TOKEN = os.environ.get("HERMES_DASHBOARD_SESSION_TOKEN", "cody-waybar-local")
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermes-waybar-voice"
PID_FILE = RUNTIME_DIR / "worker.pid"
LOCK_FILE = RUNTIME_DIR / "worker.lock"
SESSION_FILE = RUNTIME_DIR / "session.json"
STATUS_FILE = RUNTIME_DIR / "status.json"
LOG_FILE = RUNTIME_DIR / "worker.log"
STOP = False


def ensure_runtime() -> None:
    RUNTIME_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)


def read_json(path: Path) -> dict:
    try:
        with path.open() as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def write_json(path: Path, data: dict) -> None:
    ensure_runtime()
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w") as handle:
        json.dump(data, handle)
    tmp.replace(path)


def set_status(state: str, tooltip: str) -> None:
    write_json(STATUS_FILE, {"state": state, "tooltip": tooltip, "updated_at": time.time()})


def read_pid() -> int | None:
    try:
        return int(PID_FILE.read_text().strip())
    except (FileNotFoundError, ValueError, OSError):
        return None


def process_running(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def cleanup_stale_pid() -> None:
    if not process_running(read_pid()):
        try:
            PID_FILE.unlink()
        except FileNotFoundError:
            pass


def waybar_status() -> None:
    ensure_runtime()
    cleanup_stale_pid()
    running = process_running(read_pid())
    status = read_json(STATUS_FILE)
    tooltip = status.get("tooltip") if isinstance(status.get("tooltip"), str) else None
    if running:
        output = {"text": "", "tooltip": tooltip or "Hermes voice running", "class": "running"}
    else:
        output = {"text": "", "tooltip": tooltip or "Hermes voice idle", "class": "idle"}
    print(json.dumps(output), flush=True)


def stop_worker(clear_session: bool = False, hard: bool = False) -> None:
    ensure_runtime()
    pid = read_pid()
    if process_running(pid):
        os.kill(pid, signal.SIGTERM)
        deadline = time.time() + 4
        while time.time() < deadline and process_running(pid):
            time.sleep(0.1)
        if hard and process_running(pid):
            os.kill(pid, signal.SIGKILL)
    try:
        PID_FILE.unlink()
    except FileNotFoundError:
        pass
    if clear_session:
        try:
            SESSION_FILE.unlink()
        except FileNotFoundError:
            pass
    set_status("idle", "Hermes voice idle")


def start_worker() -> None:
    ensure_runtime()
    cleanup_stale_pid()
    if process_running(read_pid()):
        return
    with LOG_FILE.open("ab", buffering=0) as log:
        subprocess.Popen(
            [sys.executable, __file__, "worker"],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
            start_new_session=True,
            env=os.environ.copy(),
        )
    set_status("starting", "Hermes voice starting")


def reset_runtime(clear_session: bool, hard: bool) -> None:
    stop_worker(clear_session=clear_session, hard=hard)
    if hard:
        for path in RUNTIME_DIR.glob("*"):
            try:
                path.unlink()
            except OSError:
                pass
        set_status("idle", "Hermes voice cleaned up")


def toggle() -> None:
    ensure_runtime()
    cleanup_stale_pid()
    if process_running(read_pid()):
        stop_worker(clear_session=False, hard=False)
    else:
        start_worker()


def ws_url() -> str:
    parsed = urllib.parse.urlparse(BASE_URL)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    netloc = parsed.netloc or parsed.path
    return f"{scheme}://{netloc}/api/ws?token={urllib.parse.quote(TOKEN)}"


async def rpc(ws, method: str, params: dict | None = None) -> dict:
    rpc.counter += 1
    request_id = rpc.counter
    await ws.send(json.dumps({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}}) + "\n")
    while not STOP:
        try:
            message = await asyncio.wait_for(ws.recv(), timeout=1)
        except asyncio.TimeoutError:
            continue
        for line in str(message).splitlines():
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("id") == request_id:
                if "error" in event:
                    raise RuntimeError(str(event["error"]))
                result = event.get("result")
                return result if isinstance(result, dict) else {"value": result}
            await handle_event(event)
    raise RuntimeError("stopped")


rpc.counter = 0


async def handle_event(event: dict) -> None:
    text = transcript_from_event(event)
    if text:
        set_status("heard", f"Heard: {text[:80]}")


def nested_get(data, keys: tuple[str, ...]):
    current = data
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def event_type_and_payload(event: dict) -> tuple[str, dict]:
    method = str(event.get("method") or event.get("type") or event.get("event") or "")
    params = event.get("params") if isinstance(event.get("params"), dict) else {}
    if method == "event":
        event_type = str(params.get("type") or "")
        payload = params.get("payload") if isinstance(params.get("payload"), dict) else {}
        return event_type, payload
    return method, params if params else event


def session_id_from_result(result: dict) -> str | None:
    candidates = [
        result.get("session_id"),
        result.get("sessionId"),
        result.get("id"),
        nested_get(result, ("session", "id")),
        nested_get(result, ("session", "session_id")),
        result.get("value"),
    ]
    for candidate in candidates:
        if isinstance(candidate, str) and candidate:
            return candidate
    return None


async def open_session(ws) -> str:
    saved = read_json(SESSION_FILE).get("session_id")
    if isinstance(saved, str) and saved:
        try:
            result = await rpc(ws, "session.resume", {"session_id": saved})
            session_id = session_id_from_result(result) or saved
            write_json(SESSION_FILE, {"session_id": session_id})
            set_status("listening", "Hermes voice resumed")
            return session_id
        except Exception:
            pass
    result = await rpc(ws, "session.create", {"close_on_disconnect": False, "source": "waybar-voice"})
    session_id = session_id_from_result(result)
    if not session_id:
        raise RuntimeError("Hermes did not return a session id")
    write_json(SESSION_FILE, {"session_id": session_id})
    set_status("listening", "Hermes voice session created")
    return session_id


def transcript_from_event(event: dict) -> str | None:
    method, payload = event_type_and_payload(event)
    if "transcript" not in method and "voice" not in method and "speech" not in method:
        if not any(key in payload for key in ("transcript", "utterance")):
            return None
    text = payload.get("transcript") or payload.get("text") or payload.get("utterance")
    if not isinstance(text, str) or not text.strip():
        return None
    final_value = payload.get("final") or payload.get("is_final") or payload.get("complete")
    status = str(payload.get("status") or payload.get("state") or method).lower()
    if final_value is False and "final" not in status and "complete" not in status and "end" not in status:
        return None
    return text.strip()


async def wait_for_transcript(ws) -> str | None:
    while not STOP:
        try:
            message = await asyncio.wait_for(ws.recv(), timeout=1)
        except asyncio.TimeoutError:
            continue
        for line in str(message).splitlines():
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = transcript_from_event(event)
            if text:
                return text
            await handle_event(event)
    return None


async def wait_for_reply(ws) -> str | None:
    deltas: list[str] = []
    while not STOP:
        try:
            message = await asyncio.wait_for(ws.recv(), timeout=1)
        except asyncio.TimeoutError:
            continue
        for line in str(message).splitlines():
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            method, payload = event_type_and_payload(event)
            if method == "message.delta":
                text = payload.get("text")
                if isinstance(text, str) and text:
                    deltas.append(text)
                continue
            if method == "message.complete":
                text = payload.get("text")
                if isinstance(text, str) and text.strip():
                    return text.strip()
                reply = "".join(deltas).strip()
                return reply or None
            if method == "error":
                error_message = payload.get("message")
                if isinstance(error_message, str) and error_message:
                    raise RuntimeError(error_message)
            await handle_event(event)
    return None


def speak(text: str) -> None:
    url = f"{BASE_URL}/api/audio/speak?token={urllib.parse.quote(TOKEN)}"
    body = json.dumps({"text": text}).encode()
    request = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = json.loads(response.read().decode())
    data_url = payload.get("data_url") if isinstance(payload, dict) else None
    if not isinstance(data_url, str) or "," not in data_url:
        return
    metadata, encoded = data_url.split(",", 1)
    suffix = ".wav"
    if "mpeg" in metadata or "mp3" in metadata:
        suffix = ".mp3"
    elif "ogg" in metadata:
        suffix = ".ogg"
    audio_path = RUNTIME_DIR / f"tts-{int(time.time() * 1000)}{suffix}"
    audio_path.write_bytes(base64.b64decode(encoded))
    player = subprocess.Popen(["mpv", "--no-terminal", "--really-quiet", str(audio_path)])
    while player.poll() is None:
        if STOP:
            player.terminate()
            try:
                player.wait(timeout=2)
            except subprocess.TimeoutExpired:
                player.kill()
            break
        time.sleep(0.1)
    try:
        audio_path.unlink()
    except OSError:
        pass


async def worker_loop() -> None:
    ensure_runtime()
    with LOCK_FILE.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        PID_FILE.write_text(str(os.getpid()))
        set_status("connecting", "Hermes voice connecting")
        recording = False
        try:
            async with websockets.connect(ws_url(), ping_interval=20, ping_timeout=20) as ws:
                session_id = await open_session(ws)
                while not STOP:
                    set_status("listening", "Hermes voice listening")
                    await rpc(ws, "voice.record", {"action": "start", "session_id": session_id})
                    recording = True
                    transcript = await wait_for_transcript(ws)
                    if not transcript:
                        continue
                    recording = False
                    await rpc(ws, "voice.record", {"action": "stop", "session_id": session_id})
                    set_status("thinking", f"Hermes thinking: {transcript[:80]}")
                    await rpc(ws, "prompt.submit", {"session_id": session_id, "text": transcript})
                    reply = await wait_for_reply(ws)
                    if reply:
                        set_status("speaking", "Hermes voice speaking")
                        speak(reply)
                if recording:
                    await rpc(ws, "voice.record", {"action": "stop", "session_id": session_id})
        finally:
            try:
                PID_FILE.unlink()
            except FileNotFoundError:
                pass
            set_status("idle", "Hermes voice idle")


def request_stop(_signum, _frame) -> None:
    global STOP
    STOP = True


def main() -> int:
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    if command == "status":
        waybar_status()
    elif command == "toggle":
        toggle()
    elif command == "reset":
        reset_runtime(clear_session=True, hard=False)
    elif command == "cleanup":
        reset_runtime(clear_session=True, hard=True)
    elif command == "worker":
        asyncio.run(worker_loop())
    else:
        print(f"unknown command: {command}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
