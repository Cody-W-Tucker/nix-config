#!/usr/bin/env python3
"""OpenAI-compatible transcription server backed by sherpa-onnx.

Serves Fluid Speech Pro in clean mode behind llama-swap. The
request/response shape matches the faster-whisper wrapper it replaces so
existing clients only need to change the model id.
"""

import argparse
import asyncio
import logging
import subprocess
import threading
import time
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import sherpa_onnx
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse


logger = logging.getLogger("sherpa-onnx-openai-server")

SAMPLE_RATE = 16000


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenAI-compatible sherpa-onnx server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-dir", required=True, type=Path)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--provider", default="cpu", choices=["cpu", "cuda"])
    parser.add_argument("--num-threads", type=int, default=4)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument(
        "--max-chunk-seconds",
        type=float,
        default=120.0,
        help="Split longer audio near the quietest point before this length.",
    )
    return parser


def make_recognizer(model_dir: Path, provider: str, num_threads: int):
    return sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=str(model_dir / "encoder-model.clean.int8.onnx"),
        decoder=str(model_dir / "decoder.clean.int8.onnx"),
        joiner=str(model_dir / "joiner.clean.int8.onnx"),
        tokens=str(model_dir / "vocab.txt"),
        num_threads=num_threads,
        sample_rate=SAMPLE_RATE,
        feature_dim=128,
        decoding_method="greedy_search",
        model_type="nemo_transducer",
        provider=provider,
    )


def decode_audio(ffmpeg: str, audio_bytes: bytes) -> np.ndarray:
    # ffmpeg accepts every container clients send (WAV dictation, Ogg/Opus
    # chat voice notes, MP3/M4A uploads) and resamples to 16 kHz mono.
    proc = subprocess.run(
        [
            ffmpeg,
            "-nostdin",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            "pipe:0",
            "-ac",
            "1",
            "-ar",
            str(SAMPLE_RATE),
            "-f",
            "f32le",
            "pipe:1",
        ],
        input=audio_bytes,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        detail = proc.stderr.decode(errors="replace").strip() or "ffmpeg failed"
        raise HTTPException(status_code=400, detail=f"Could not decode audio: {detail}")
    return np.frombuffer(proc.stdout, dtype=np.float32)


def split_samples(samples: np.ndarray, max_seconds: float) -> list[np.ndarray]:
    max_len = int(max_seconds * SAMPLE_RATE)
    if max_len <= 0 or len(samples) <= max_len:
        return [samples]

    frame = SAMPLE_RATE // 10  # 100 ms energy frames
    search = min(10 * SAMPLE_RATE, max_len // 2)
    chunks = []
    start = 0
    while len(samples) - start > max_len:
        window = samples[start + max_len - search : start + max_len]
        frames = len(window) // frame
        energy = np.square(window[: frames * frame].reshape(frames, frame)).mean(axis=1)
        cut = start + max_len - search + int(np.argmin(energy)) * frame + frame // 2
        chunks.append(samples[start:cut])
        start = cut
    chunks.append(samples[start:])
    return chunks


def create_app(args: argparse.Namespace) -> FastAPI:
    lock = threading.Lock()

    def transcribe_samples(samples: np.ndarray) -> str:
        recognizer = app.state.recognizer
        texts = []
        with lock:
            for chunk in split_samples(samples, args.max_chunk_seconds):
                stream = recognizer.create_stream()
                stream.accept_waveform(SAMPLE_RATE, chunk)
                recognizer.decode_stream(stream)
                texts.append(stream.result.text.strip())
        return " ".join(t for t in texts if t)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        started = time.monotonic()
        app.state.recognizer = make_recognizer(args.model_dir, args.provider, args.num_threads)
        # Run one decode before /health succeeds so llama-swap only routes
        # requests once the provider session is initialised and warm.
        transcribe_samples(np.zeros(SAMPLE_RATE, dtype=np.float32))
        logger.warning(
            "Loaded %s from %s with provider=%s in %.1fs",
            args.model_id,
            args.model_dir,
            args.provider,
            time.monotonic() - started,
        )
        yield

    app = FastAPI(lifespan=lifespan)

    @app.get("/")
    async def root():
        return {"status": "ok", "model": args.model_id, "provider": args.provider}

    @app.get("/health")
    @app.get("/v1/health")
    async def health():
        return {"status": "ok", "provider": args.provider}

    @app.get("/models")
    @app.get("/v1/models")
    async def models():
        return {
            "object": "list",
            "data": [{"id": args.model_id, "object": "model", "owned_by": "local"}],
        }

    @app.post("/audio/transcriptions")
    @app.post("/v1/audio/transcriptions")
    async def transcriptions(
        file: UploadFile = File(...),
        language: str | None = Form(default=None),
        model: str | None = Form(default=None),
        prompt: str | None = Form(default=None),
        response_format: str | None = Form(default=None),
        temperature: str | None = Form(default=None),
        task: str | None = Form(default=None),
    ):
        # Fluid Speech Pro detects its 25 European languages itself and has no
        # prompt or sampling controls; accept and ignore those fields.
        del model, prompt, temperature

        if task not in (None, "transcribe"):
            raise HTTPException(status_code=422, detail="Only task=transcribe is supported")

        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")

        samples = await asyncio.to_thread(decode_audio, args.ffmpeg, audio_bytes)
        duration = len(samples) / SAMPLE_RATE
        text = await asyncio.to_thread(transcribe_samples, samples) if len(samples) else ""

        if response_format == "text":
            return PlainTextResponse(text)
        body = {"text": text}
        if language:
            body["language"] = language
        if response_format == "verbose_json":
            body.update({"task": "transcribe", "duration": duration, "segments": []})
        return JSONResponse(body)

    return app


def main():
    logging.basicConfig(level=logging.INFO)
    args = build_parser().parse_args()
    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
