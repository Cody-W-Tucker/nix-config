#!/usr/bin/env python3
import fcntl
import json
import os
import queue
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import wave
from collections import deque
from pathlib import Path


HERMES_BASE_URL = os.environ.get("HERMES_BASE_URL", "http://127.0.0.1:8642").rstrip("/")
SPEECH_BASE_URL = os.environ.get(
    "HERMES_SPEECH_BASE_URL", "http://127.0.0.1:8081"
).rstrip("/")
AUTH_TOKEN = os.environ.get("HERMES_API_TOKEN", "local-only")
CHAT_MODEL = os.environ.get("HERMES_CHAT_MODEL", "local")
TRANSCRIPTION_MODEL = os.environ.get("HERMES_TRANSCRIPTION_MODEL", "whisper-medium")
SPEECH_MODEL = os.environ.get("HERMES_SPEECH_MODEL", "kokoro-82m")
SPEECH_VOICE = os.environ.get("HERMES_SPEECH_VOICE", "af_heart")
MAX_MESSAGES = int(os.environ.get("HERMES_VOICE_MAX_MESSAGES", "24"))
CHAT_TIMEOUT_SECONDS = float(os.environ.get("HERMES_CHAT_TIMEOUT_SECONDS", "300"))

AUDIO_RATE = int(os.environ.get("HERMES_VOICE_SAMPLE_RATE", "16000"))
AUDIO_CHANNELS = 1
AUDIO_SAMPLE_WIDTH = 2
FRAME_MS = int(os.environ.get("HERMES_VOICE_FRAME_MS", "30"))
FRAME_SAMPLES = max(1, AUDIO_RATE * FRAME_MS // 1000)
FRAME_BYTES = FRAME_SAMPLES * AUDIO_SAMPLE_WIDTH * AUDIO_CHANNELS
FRAME_SECONDS = FRAME_SAMPLES / AUDIO_RATE
START_RMS = int(os.environ.get("HERMES_VOICE_START_RMS", "700"))
SILENCE_RMS = int(os.environ.get("HERMES_VOICE_SILENCE_RMS", "350"))
START_NOISE_MULTIPLIER = float(
    os.environ.get("HERMES_VOICE_START_NOISE_MULTIPLIER", "3.0")
)
SILENCE_NOISE_MULTIPLIER = float(
    os.environ.get("HERMES_VOICE_SILENCE_NOISE_MULTIPLIER", "1.8")
)
START_FRAMES = int(os.environ.get("HERMES_VOICE_START_FRAMES", "2"))
PRE_ROLL_SECONDS = float(os.environ.get("HERMES_VOICE_PRE_ROLL_SECONDS", "0.3"))
MIN_UTTERANCE_SECONDS = float(
    os.environ.get("HERMES_VOICE_MIN_UTTERANCE_SECONDS", "0.35")
)
TRAILING_SILENCE_SECONDS = float(
    os.environ.get("HERMES_VOICE_TRAILING_SILENCE_SECONDS", "1.4")
)
MAX_UTTERANCE_SECONDS = float(
    os.environ.get("HERMES_VOICE_MAX_UTTERANCE_SECONDS", "90")
)
MAX_AUDIO_QUEUE_SECONDS = float(
    os.environ.get("HERMES_VOICE_MAX_AUDIO_QUEUE_SECONDS", "5")
)

RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermes-waybar-voice"
PID_FILE = RUNTIME_DIR / "worker.pid"
LOCK_FILE = RUNTIME_DIR / "worker.lock"
SESSION_FILE = RUNTIME_DIR / "session.json"
STATUS_FILE = RUNTIME_DIR / "status.json"
LOG_FILE = RUNTIME_DIR / "worker.log"
STOP = False
INTERRUPT = False


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
    write_json(
        STATUS_FILE, {"state": state, "tooltip": tooltip, "updated_at": time.time()}
    )


def interrupt_requested() -> bool:
    return INTERRUPT and not STOP


def consume_interrupt() -> bool:
    global INTERRUPT
    was_requested = INTERRUPT
    INTERRUPT = False
    return was_requested


def compact_text(text: str, limit: int = 28) -> str:
    normalized = " ".join(text.split())
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 1].rstrip() + "…"


def session_title() -> str | None:
    messages = read_json(SESSION_FILE).get("messages")
    if not isinstance(messages, list):
        return None
    for preferred_role in ("user", "assistant", "system"):
        for message in messages:
            if not isinstance(message, dict):
                continue
            if message.get("role") != preferred_role:
                continue
            content = message.get("content")
            if isinstance(content, str) and content.strip():
                return compact_text(content)
    return None


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
    title = session_title()
    if running:
        output = {
            "text": f" {title}" if title else " Hermes",
            "tooltip": tooltip or "Hermes voice running",
            "class": "running",
        }
    elif title:
        output = {
            "text": f" {title}",
            "tooltip": tooltip or "Hermes voice ready to resume",
            "class": "paused",
        }
    else:
        output = {
            "text": "",
            "tooltip": tooltip or "Hermes voice idle",
            "class": "empty",
        }
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
    set_status("idle", "Hermes voice cleared" if clear_session else "Hermes voice idle")


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


def click() -> None:
    ensure_runtime()
    cleanup_stale_pid()
    pid = read_pid()
    if process_running(pid):
        os.kill(pid, signal.SIGUSR1)
        set_status("interrupting", "Hermes voice interrupting")
    else:
        start_worker()


def pause() -> None:
    stop_worker(clear_session=False, hard=False)


def load_messages() -> list[dict[str, str]]:
    messages = read_json(SESSION_FILE).get("messages")
    if not isinstance(messages, list):
        return []
    clean: list[dict[str, str]] = []
    for message in messages:
        if not isinstance(message, dict):
            continue
        role = message.get("role")
        content = message.get("content")
        if (
            role in {"system", "user", "assistant"}
            and isinstance(content, str)
            and content.strip()
        ):
            clean.append({"role": role, "content": content})
    return clean[-MAX_MESSAGES:]


def save_messages(messages: list[dict[str, str]]) -> None:
    trimmed = messages[-MAX_MESSAGES:]
    title = None
    for message in trimmed:
        if (
            message.get("role") == "user"
            and isinstance(message.get("content"), str)
            and message["content"].strip()
        ):
            title = compact_text(message["content"])
            break
    write_json(SESSION_FILE, {"messages": trimmed, "title": title})


def http_json(url: str, payload: dict, timeout: float = CHAT_TIMEOUT_SECONDS) -> dict:
    body = json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {AUTH_TOKEN}",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode())
    return data if isinstance(data, dict) else {}


def iter_sse_data(response):
    data_lines: list[str] = []
    for raw_line in response:
        line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
        if not line:
            if data_lines:
                yield "\n".join(data_lines)
                data_lines = []
            continue
        if line.startswith(":"):
            continue
        if line.startswith("data:"):
            data_lines.append(line[5:].lstrip())
    if data_lines:
        yield "\n".join(data_lines)


def chunk_text(payload: dict) -> str:
    choices = payload.get("choices")
    if not isinstance(choices, list):
        return ""
    parts: list[str] = []
    for choice in choices:
        if not isinstance(choice, dict):
            continue
        delta = choice.get("delta")
        if isinstance(delta, dict) and isinstance(delta.get("content"), str):
            parts.append(delta["content"])
        message = choice.get("message")
        if isinstance(message, dict) and isinstance(message.get("content"), str):
            parts.append(message["content"])
        text = choice.get("text")
        if isinstance(text, str):
            parts.append(text)
    return "".join(parts)


def http_chat_stream(
    url: str, payload: dict, timeout: float = CHAT_TIMEOUT_SECONDS
) -> str | None:
    body = json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "Authorization": f"Bearer {AUTH_TOKEN}",
        },
        method="POST",
    )
    parts: list[str] = []
    with urllib.request.urlopen(request, timeout=timeout) as response:
        for data in iter_sse_data(response):
            if interrupt_requested():
                return None
            if data.strip() == "[DONE]":
                break
            try:
                payload = json.loads(data)
            except json.JSONDecodeError:
                continue
            if not isinstance(payload, dict):
                continue
            text = chunk_text(payload)
            if text:
                parts.append(text)
    reply = "".join(parts).strip()
    return reply or None


def run_command_interruptibly(command: list[str]) -> subprocess.CompletedProcess[str] | None:
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    while process.poll() is None:
        if STOP or interrupt_requested():
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
            return None
        time.sleep(0.1)

    stdout, stderr = process.communicate()
    if process.returncode:
        raise subprocess.CalledProcessError(process.returncode, command, stdout, stderr)
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


class PipewireAudioStream:
    def __init__(self) -> None:
        self.queue: queue.Queue[bytes] = queue.Queue(
            maxsize=max(1, int(MAX_AUDIO_QUEUE_SECONDS / FRAME_SECONDS))
        )
        self.process: subprocess.Popen[bytes] | None = None
        self.reader: threading.Thread | None = None

    def __enter__(self) -> "PipewireAudioStream":
        command = [
            "pw-record",
            "--target",
            "@DEFAULT_AUDIO_SOURCE@",
            "--rate",
            str(AUDIO_RATE),
            "--channels",
            str(AUDIO_CHANNELS),
            "--format",
            "s16",
            "-",
        ]
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        self.reader = threading.Thread(target=self._read_frames, daemon=True)
        self.reader.start()
        return self

    def __exit__(self, _exc_type, _exc_value, _traceback) -> None:
        self.close()

    def _read_frames(self) -> None:
        if self.process is None or self.process.stdout is None:
            return
        while True:
            frame = self.process.stdout.read(FRAME_BYTES)
            if not frame:
                return
            if len(frame) < FRAME_BYTES:
                continue
            try:
                self.queue.put_nowait(frame)
            except queue.Full:
                try:
                    self.queue.get_nowait()
                except queue.Empty:
                    pass
                try:
                    self.queue.put_nowait(frame)
                except queue.Full:
                    pass

    def read_frame(self, timeout: float = 0.2) -> bytes | None:
        try:
            return self.queue.get(timeout=timeout)
        except queue.Empty:
            return None

    def drain(self) -> None:
        while True:
            try:
                self.queue.get_nowait()
            except queue.Empty:
                return

    def running(self) -> bool:
        return self.process is not None and self.process.poll() is None

    def close(self) -> None:
        if self.process is None or self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=2)


def frame_rms(frame: bytes) -> int:
    sample_count = len(frame) // AUDIO_SAMPLE_WIDTH
    if sample_count <= 0:
        return 0
    total = 0
    for index in range(0, len(frame) - 1, AUDIO_SAMPLE_WIDTH):
        sample = int.from_bytes(
            frame[index : index + AUDIO_SAMPLE_WIDTH], "little", signed=True
        )
        total += sample * sample
    return int((total / sample_count) ** 0.5)


def write_wav(path: Path, frames: list[bytes]) -> None:
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(AUDIO_CHANNELS)
        wav.setsampwidth(AUDIO_SAMPLE_WIDTH)
        wav.setframerate(AUDIO_RATE)
        wav.writeframes(b"".join(frames))


def record_utterance(audio: PipewireAudioStream, path: Path) -> bool:
    set_status("listening", "Hermes voice listening")
    audio.drain()
    pre_roll: deque[bytes] = deque(maxlen=max(1, int(PRE_ROLL_SECONDS / FRAME_SECONDS)))
    noise_floor = SILENCE_RMS
    loud_frames = 0
    frames: list[bytes] | None = None
    silence_seconds = 0.0

    while not STOP:
        if interrupt_requested():
            return False
        frame = audio.read_frame()
        if frame is None:
            if not audio.running():
                raise RuntimeError("pw-record stopped while Hermes was listening")
            continue

        rms = frame_rms(frame)
        if frames is None:
            pre_roll.append(frame)
            start_threshold = max(START_RMS, int(noise_floor * START_NOISE_MULTIPLIER))
            if rms >= start_threshold:
                loud_frames += 1
            else:
                loud_frames = 0
                noise_floor = (noise_floor * 0.95) + (rms * 0.05)
            if loud_frames >= START_FRAMES:
                frames = list(pre_roll)
                silence_seconds = 0.0
                set_status("recording", "Hermes voice capturing speech")
            continue

        frames.append(frame)
        elapsed = len(frames) * FRAME_SECONDS
        silence_threshold = max(
            SILENCE_RMS, int(noise_floor * SILENCE_NOISE_MULTIPLIER)
        )
        if rms < silence_threshold:
            silence_seconds += FRAME_SECONDS
        else:
            silence_seconds = 0.0

        if elapsed >= MAX_UTTERANCE_SECONDS:
            break
        if (
            elapsed >= MIN_UTTERANCE_SECONDS
            and silence_seconds >= TRAILING_SILENCE_SECONDS
        ):
            break

    if STOP or not frames:
        return False
    write_wav(path, frames)
    return path.exists() and path.stat().st_size > 1024


def transcribe(path: Path) -> str | None:
    set_status("transcribing", "Hermes voice transcribing")
    result = run_command_interruptibly(
        [
            "curl",
            "-sS",
            "-X",
            "POST",
            f"{SPEECH_BASE_URL}/v1/audio/transcriptions",
            "-H",
            f"Authorization: Bearer {AUTH_TOKEN}",
            "-F",
            f"model={TRANSCRIPTION_MODEL}",
            "-F",
            f"file=@{path};type=audio/wav",
        ]
    )
    if result is None:
        return None
    payload = json.loads(result.stdout)
    text = payload.get("text") if isinstance(payload, dict) else None
    if not isinstance(text, str) or not text.strip():
        return None
    return text.strip()


def chat(messages: list[dict[str, str]]) -> str | None:
    return http_chat_stream(
        f"{HERMES_BASE_URL}/v1/chat/completions",
        {"model": CHAT_MODEL, "messages": messages, "stream": True},
    )


def speech_suffix(content_type: str) -> str:
    if "mpeg" in content_type or "mp3" in content_type:
        return ".mp3"
    if "ogg" in content_type:
        return ".ogg"
    return ".wav"


def synthesize(text: str) -> Path | None:
    set_status("speaking", "Hermes voice synthesizing")
    request_path = RUNTIME_DIR / f"tts-request-{int(time.time() * 1000)}.json"
    headers_path = RUNTIME_DIR / f"tts-headers-{int(time.time() * 1000)}.txt"
    audio_path = RUNTIME_DIR / f"tts-{int(time.time() * 1000)}.wav"
    result_path: Path | None = None
    request_path.write_text(
        json.dumps({"model": SPEECH_MODEL, "voice": SPEECH_VOICE, "input": text})
    )
    try:
        result = run_command_interruptibly(
            [
                "curl",
                "-sS",
                "-D",
                str(headers_path),
                "-X",
                "POST",
                f"{SPEECH_BASE_URL}/v1/audio/speech",
                "-H",
                f"Authorization: Bearer {AUTH_TOKEN}",
                "-H",
                "Content-Type: application/json",
                "--data-binary",
                f"@{request_path}",
                "-o",
                str(audio_path),
            ]
        )
        if result is None or interrupt_requested():
            return None
        if not audio_path.exists() or audio_path.stat().st_size == 0:
            return None
        content_type = "audio/wav"
        try:
            for line in headers_path.read_text().splitlines():
                if line.lower().startswith("content-type:"):
                    content_type = line.split(":", 1)[1].strip()
                    break
        except OSError:
            pass
        final_path = audio_path.with_suffix(speech_suffix(content_type))
        if final_path != audio_path:
            audio_path.replace(final_path)
            audio_path = final_path
        result_path = audio_path
        return result_path
    finally:
        for temp_path in (request_path, headers_path):
            try:
                temp_path.unlink()
            except OSError:
                pass
        if result_path is None:
            try:
                audio_path.unlink()
            except OSError:
                pass


def play_audio(path: Path) -> None:
    set_status("speaking", "Hermes voice speaking")
    players = (
        [["mpv", "--no-terminal", "--really-quiet", str(path)]]
        if path.suffix == ".mp3"
        else [
            ["pw-play", str(path)],
            ["mpv", "--no-terminal", "--really-quiet", str(path)],
        ]
    )
    for command in players:
        try:
            player = subprocess.Popen(command, stdin=subprocess.DEVNULL)
            break
        except FileNotFoundError:
            player = None
    if player is None:
        return
    while player.poll() is None:
        if STOP or interrupt_requested():
            player.terminate()
            try:
                player.wait(timeout=2)
            except subprocess.TimeoutExpired:
                player.kill()
            break
        time.sleep(0.1)


def worker_loop() -> None:
    ensure_runtime()
    with LOCK_FILE.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        PID_FILE.write_text(str(os.getpid()))
        set_status("starting", "Hermes voice starting")
        try:
            messages = load_messages()
            while not STOP:
                with PipewireAudioStream() as audio:
                    with tempfile.NamedTemporaryFile(
                        prefix="utterance-",
                        suffix=".wav",
                        dir=RUNTIME_DIR,
                        delete=False,
                    ) as handle:
                        utterance_path = Path(handle.name)
                    utterance_path.unlink(missing_ok=True)
                    try:
                        if not record_utterance(audio, utterance_path):
                            if consume_interrupt():
                                set_status("listening", "Hermes voice listening")
                            continue
                        transcript = transcribe(utterance_path)
                    finally:
                        try:
                            utterance_path.unlink()
                        except OSError:
                            pass
                if consume_interrupt() or not transcript:
                    set_status("listening", "Hermes voice listening")
                    continue
                set_status("thinking", f"Hermes thinking: {transcript[:80]}")
                messages.append({"role": "user", "content": transcript})
                messages = messages[-MAX_MESSAGES:]
                reply = chat(messages)
                if consume_interrupt() or not reply:
                    set_status("listening", "Hermes voice listening")
                    continue
                messages.append({"role": "assistant", "content": reply})
                messages = messages[-MAX_MESSAGES:]
                save_messages(messages)
                audio_path = synthesize(reply)
                if audio_path:
                    try:
                        play_audio(audio_path)
                    finally:
                        try:
                            audio_path.unlink()
                        except OSError:
                            pass
                if consume_interrupt():
                    set_status("listening", "Hermes voice listening")
        except (
            OSError,
            urllib.error.URLError,
            subprocess.SubprocessError,
            json.JSONDecodeError,
        ) as error:
            set_status("error", f"Hermes voice error: {error}")
            raise
        finally:
            try:
                PID_FILE.unlink()
            except FileNotFoundError:
                pass
            if STOP:
                set_status("idle", "Hermes voice idle")


def request_stop(_signum, _frame) -> None:
    global STOP
    STOP = True


def request_interrupt(_signum, _frame) -> None:
    global INTERRUPT
    INTERRUPT = True


def main() -> int:
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGUSR1, request_interrupt)
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    if command == "status":
        waybar_status()
    elif command == "click":
        click()
    elif command == "pause":
        pause()
    elif command == "reset":
        reset_runtime(clear_session=True, hard=False)
    elif command == "cleanup":
        reset_runtime(clear_session=True, hard=True)
    elif command == "worker":
        worker_loop()
    else:
        print(f"unknown command: {command}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
