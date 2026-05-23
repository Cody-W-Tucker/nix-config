#!/usr/bin/env python3

import argparse
import os
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenAI-compatible faster-whisper server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--compute-type", default="int8")
    parser.add_argument("--download-root", default=None)
    parser.add_argument("--language", default=None)
    parser.add_argument("--beam-size", type=int, default=5)
    parser.add_argument("--vad-filter", action="store_true")
    return parser


def create_app(args: argparse.Namespace) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.model = WhisperModel(
            args.model,
            device=args.device,
            compute_type=args.compute_type,
            download_root=args.download_root,
        )
        app.state.model_id = args.model_id
        app.state.default_language = args.language
        app.state.beam_size = args.beam_size
        app.state.vad_filter = args.vad_filter
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

    @app.post("/audio/transcriptions")
    @app.post("/v1/audio/transcriptions")
    async def transcriptions(
        file: UploadFile = File(...),
        language: str | None = Form(default=None),
        model: str | None = Form(default=None),
        prompt: str | None = Form(default=None),
        response_format: str | None = Form(default=None),
        temperature: str | None = Form(default=None),
    ):
        del model, prompt, response_format, temperature

        suffix = Path(file.filename or "audio.wav").suffix or ".wav"
        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")

        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
                temp_file.write(audio_bytes)
                temp_path = temp_file.name

            segments, info = app.state.model.transcribe(
                temp_path,
                beam_size=app.state.beam_size,
                vad_filter=app.state.vad_filter,
                language=language or app.state.default_language,
            )

            text = "".join(segment.text for segment in segments).strip()
            return JSONResponse(
                {
                    "text": text,
                    "language": info.language,
                }
            )
        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)

    return app


def main():
    args = build_parser().parse_args()
    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
