#!/usr/bin/env python3

import argparse
import io
import wave
from contextlib import asynccontextmanager
import numpy as np
import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from kokoro import KPipeline
from pydantic import BaseModel

# Map OpenAI (and other common) voice names to Kokoro voices.
# llama-server and OpenAI clients default to these names for /v1/audio/speech.
# We ship a small set of Kokoro assets via pkgs.kokoro.
VOICE_MAP = {
    "alloy": "af_alloy",
    "echo": "am_adam",
    "fable": "af_bella",
    "onyx": "am_michael",
    "nova": "af_heart",
    "shimmer": "af_sky",
    # Seen in the wild causing 404 on coral.pt; map to a reliable default.
    "coral": "af_heart",
}


def _normalize_voice(v: str | None) -> str:
    if not v:
        return v or ""
    v = v.lower()
    if v.endswith(".pt"):
        v = v[:-3]
    return VOICE_MAP.get(v, v)


def _install_local_voice_provider(voices_dir: str) -> None:
    """Patch so that kokoro's hf_hub_download calls for voices/*.pt are served
    from the pre-fetched pkgs.kokoro directory. This must be done after
    the top-level `from kokoro import ...` because kokoro.pipeline binds
    hf_hub_download into its module globals at import time.
    Unknown / unshipped voices fall through to the real hf_hub_download.
    """
    from pathlib import Path
    import sys

    import huggingface_hub as hfh

    orig = hfh.hf_hub_download
    vdir = Path(voices_dir)

    def local_or_orig(repo_id: str, filename: str, **kw):
        if filename.startswith("voices/"):
            name = filename.split("/", 1)[1]
            p = vdir / name
            if p.exists():
                return str(p)
        return orig(repo_id=repo_id, filename=filename, **kw)

    # Patch the public entry point
    hfh.hf_hub_download = local_or_orig

    # Also patch the submodule where the implementation actually lives in
    # modern huggingface_hub; kokoro sometimes imports from here directly.
    try:
        import huggingface_hub.file_download as _fd  # type: ignore

        if hasattr(_fd, "hf_hub_download"):
            _fd.hf_hub_download = local_or_orig
    except Exception:
        pass

    # Re-bind the name in any already-imported kokoro submodules.
    # This covers `from huggingface_hub import hf_hub_download` done at
    # kokoro import time; name lookup inside those modules will now find ours.
    for mod_name in ("kokoro.pipeline", "kokoro.model"):
        mod = sys.modules.get(mod_name)
        if mod is not None:
            if hasattr(mod, "hf_hub_download"):
                mod.hf_hub_download = local_or_orig

    # Explicit imports in case sys.modules lookup was too early
    try:
        import kokoro.pipeline as kp  # type: ignore

        kp.hf_hub_download = local_or_orig
    except Exception:
        pass

    try:
        import kokoro.model as km  # type: ignore

        km.hf_hub_download = local_or_orig
    except Exception:
        pass

    try:
        import kokoro.model as km  # type: ignore

        km.hf_hub_download = local_or_orig
    except Exception:
        pass


def _audio_to_wav_bytes(audio: np.ndarray, sample_rate: int = 24000) -> bytes:
    audio = np.asarray(audio, dtype=np.float32)
    if audio.ndim != 1:
        audio = np.squeeze(audio)
    audio = np.clip(audio, -1.0, 1.0)
    pcm16 = (audio * 32767.0).astype(np.int16)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm16.tobytes())
    return buf.getvalue()


class SpeechRequest(BaseModel):
    model: str | None = None
    input: str
    voice: str | None = None
    speed: float = 1.0
    response_format: str | None = "wav"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenAI-compatible Kokoro TTS server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--lang-code", default="a", help="Kokoro language code (a=American, b=British, etc.)")
    parser.add_argument("--repo-id", default="hexgrad/Kokoro-82M")
    parser.add_argument("--default-voice", default="af_heart")
    parser.add_argument(
        "--voices-dir",
        default=None,
        help="Directory of pre-fetched <voice>.pt files (e.g. from pkgs.kokoro) for fully offline use",
    )
    parser.add_argument(
        "--model-path",
        default=None,
        help="Path to pre-fetched kokoro-v1_0.pth (or equivalent) from pkgs.kokoro",
    )
    parser.add_argument(
        "--config-path",
        default=None,
        help="Path to pre-fetched config.json from pkgs.kokoro",
    )
    return parser


def create_app(args: argparse.Namespace) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        repo_id = args.repo_id
        voices_dir = args.voices_dir
        if voices_dir:
            _install_local_voice_provider(voices_dir)

        # Prefer explicit pre-fetched model files (from pkgs.kokoro) so we
        # never hit the network for the big weights/config at startup.
        kmodel = None
        if args.model_path and args.config_path:
            from kokoro.model import KModel

            device = "cuda" if torch.cuda.is_available() else "cpu"

            kmodel = KModel(
                repo_id=repo_id,
                config=args.config_path,
                model=args.model_path,
                # The default complex STFT path has been flaky here with local
                # preloaded models, surfacing as "could not create a primitive"
                # during synthesis.
                disable_complex=True,
            ).to(device).eval()

        app.state.pipeline = KPipeline(lang_code=args.lang_code, repo_id=repo_id, model=kmodel or True)
        app.state.model_id = args.model_id
        app.state.default_voice = args.default_voice
        app.state.voices_dir = voices_dir
        yield

    app = FastAPI(lifespan=lifespan)

    @app.get("/")
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
        vdir = getattr(app.state, "voices_dir", None)
        if vdir:
            from pathlib import Path

            p = Path(vdir)
            names = sorted(
                x.stem
                for x in p.glob("*.pt")
                if x.is_file()
            )
            return {"object": "list", "data": [{"id": n, "object": "voice"} for n in names]}
        # Fallback: report the configured default (so clients see something)
        dv = getattr(app.state, "default_voice", None)
        return {
            "object": "list",
            "data": ([{"id": dv, "object": "voice"}] if dv else []),
        }

    @app.post("/audio/speech")
    @app.post("/v1/audio/speech")
    async def speech(payload: SpeechRequest):
        text = (payload.input or "").strip()
        if not text:
            raise HTTPException(status_code=400, detail="Missing input text")

        voice = _normalize_voice(payload.voice or app.state.default_voice)
        speed = float(payload.speed) if payload.speed else 1.0

        try:
            generator = app.state.pipeline(text, voice=voice, speed=speed)
            chunks = []
            for _gs, _ps, audio in generator:
                if audio is not None:
                    chunks.append(np.asarray(audio).squeeze())
            if not chunks:
                raise HTTPException(status_code=500, detail="No audio generated")
            audio = np.concatenate(chunks) if len(chunks) > 1 else chunks[0]
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Kokoro generation failed: {e}") from e

        return Response(content=_audio_to_wav_bytes(audio), media_type="audio/wav")

    return app


def main():
    args = build_parser().parse_args()
    import uvicorn

    uvicorn.run(create_app(args), host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
