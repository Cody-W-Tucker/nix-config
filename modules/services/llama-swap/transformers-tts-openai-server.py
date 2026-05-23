#!/usr/bin/env python3

import argparse
import io
import os
import wave
import zipfile
from contextlib import asynccontextmanager

import numpy as np
import torch
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from huggingface_hub import hf_hub_download
from pydantic import BaseModel
from transformers import pipeline


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenAI-compatible SpeechT5 server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--default-voice", default="")
    parser.add_argument("--default-speaker-index", type=int, default=6799)
    parser.add_argument("--device", default="auto")
    return parser


class SpeechRequest(BaseModel):
    input: str
    model: str | None = None
    voice: str | None = None
    response_format: str | None = None
    speed: float | None = None


def resolve_pipeline_device(device: str) -> int | None:
    if device == "cuda" or (device == "auto" and torch.cuda.is_available()):
        return 0
    return None


def load_speaker_catalog(cache_dir: str):
    zip_path = hf_hub_download(
        repo_id="Matthijs/cmu-arctic-xvectors",
        filename="spkrec-xvect.zip",
        repo_type="dataset",
        cache_dir=cache_dir,
    )

    with zipfile.ZipFile(zip_path) as archive:
        entries = sorted(
            name for name in archive.namelist() if name.endswith(".npy")
        )

    return zip_path, entries


def resolve_speaker_entry(voice: str, speaker_entries: list[str], default_index: int) -> str:
    speaker_key = (voice or "").strip().lower()
    if speaker_key:
        for entry in speaker_entries:
            filename = os.path.splitext(os.path.basename(entry))[0].lower()
            if filename == speaker_key or filename.startswith(f"{speaker_key}_"):
                return entry

    clamped_index = min(max(default_index, 0), len(speaker_entries) - 1)
    return speaker_entries[clamped_index]


def load_speaker_embedding(zip_path: str, entry_name: str) -> torch.Tensor:
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open(entry_name) as embedding_file:
            embedding = np.load(embedding_file)

    return torch.tensor(embedding).unsqueeze(0)


def encode_wav(audio: np.ndarray, sample_rate: int) -> bytes:
    clipped = np.clip(audio, -1.0, 1.0)
    pcm16 = (clipped * 32767.0).astype(np.int16)

    output = io.BytesIO()
    with wave.open(output, "wb") as wav_file:
      wav_file.setnchannels(1)
      wav_file.setsampwidth(2)
      wav_file.setframerate(sample_rate)
      wav_file.writeframes(pcm16.tobytes())

    return output.getvalue()


def create_app(args: argparse.Namespace) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        pipeline_device = resolve_pipeline_device(args.device)
        app.state.speech_synthesiser = pipeline(
            "text-to-speech",
            "microsoft/speecht5_tts",
            device=pipeline_device,
        )
        cache_dir = os.environ.get("HF_HOME") or os.environ.get("XDG_CACHE_HOME")
        app.state.speaker_zip_path, app.state.speaker_entries = load_speaker_catalog(cache_dir)
        app.state.model_id = args.model_id
        app.state.default_voice = args.default_voice
        app.state.default_speaker_index = args.default_speaker_index
        yield

    app = FastAPI(lifespan=lifespan)

    @app.get("/health")
    @app.get("/v1/health")
    async def health():
        return {"status": "ok"}

    @app.get("/models")
    @app.get("/v1/models")
    async def models():
        return {
            "object": "list",
            "data": [
                {
                    "id": app.state.model_id,
                    "object": "model",
                    "owned_by": "local",
                }
            ],
        }

    @app.get("/audio/voices")
    @app.get("/v1/audio/voices")
    async def voices():
        voices = []
        if app.state.default_voice:
            voices.append({"id": app.state.default_voice, "object": "voice"})
        return {"object": "list", "data": voices}

    @app.post("/audio/speech")
    @app.post("/v1/audio/speech")
    async def speech(payload: SpeechRequest):
        text = payload.input.strip()
        if not text:
            raise HTTPException(status_code=400, detail="Missing input text")

        speaker_entry = resolve_speaker_entry(
            payload.voice or app.state.default_voice,
            app.state.speaker_entries,
            app.state.default_speaker_index,
        )
        speaker_embedding = load_speaker_embedding(app.state.speaker_zip_path, speaker_entry)
        speech_result = app.state.speech_synthesiser(
            text,
            forward_params={"speaker_embeddings": speaker_embedding},
        )
        wav_audio = encode_wav(speech_result["audio"], speech_result["sampling_rate"])
        return Response(content=wav_audio, media_type="audio/wav")

    return app


def main():
    args = build_parser().parse_args()
    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
