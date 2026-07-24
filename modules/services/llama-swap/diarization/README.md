# Diarization server package

WhisperX-based speaker diarization server for the llama-swap audio stack.
Runs as a managed upstream behind llama-swap on `beast`.

## Responsibilities

- **Speaker-aware transcription**: WhisperX ASR → word-level alignment → pyannote diarization → speaker-labeled segments.
- **Speaker enrollment**: persistent voice profiles (embeddings only, no raw audio retained) with consent tracking and revision-based staleness detection.
- **Embedding cache**: per-recording prototype embeddings keyed by content hash (audio + transcript + segment set). Survives transcript re-runs; invalidated by any input change.
- **Candidate matching**: advisory speaker-identity suggestions via cosine similarity against enrolled profiles. Always flagged as review-only.

## Customer workflow

The primary consumer is the meeting-transcription pipeline in `/home/codyt/Knowledge/Customers`. Recordings are transcribed with diarization, embeddings are cached per-recording, and candidate matching runs against enrolled speakers on request.

1. **Transcribe**: `POST /v1/audio/transcriptions` with audio file. Returns diarized segments with anonymous speaker labels.
2. **Enroll speakers** (optional): `POST /v1/identity/enroll` (with consent) → `POST /v1/identity/samples` (≥3 audio samples per person).
3. **Identify**: `POST /v1/audio/transcriptions` with `identity_mode=candidates` returns per-speaker candidate matches.
4. **Cache build**: `POST /v1/identity/cache/build` with audio + transcript JSON. Builds/reuses embedding cache.
5. **Cache candidates**: `POST /v1/identity/cache/candidates` for batch candidate lookup from cached prototypes.

## Stable endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/`, `/health`, `/v1/health` | Health check |
| GET | `/models`, `/v1/models` | Model listing |
| POST | `/audio/transcriptions`, `/v1/audio/transcriptions` | Transcribe + diarize |
| POST | `/v1/identity/enroll` | Initialize enrollment |
| POST | `/v1/identity/samples` | Upload enrollment audio |
| GET | `/v1/identity/candidates` | List candidate-eligible persons |
| GET | `/v1/identity/status/{person_id}` | Enrollment metadata |
| GET | `/v1/identity/inventory` | All enrolled persons |
| POST | `/v1/identity/cache/build` | Build embedding cache |
| POST | `/v1/identity/cache/candidates` | Batch candidate lookup |

## Storage and privacy

- **Enrollment**: `/var/lib/llama-swap/diarization/enrollment/<person_id>/` — metadata.json + embeddings.json (0600).
- **Embedding cache**: `/var/lib/llama-swap/diarization/embedding-cache/<cache_id>/` — manifest.json + prototypes.json (0600).
- **No raw audio is retained** after embedding extraction. Only 192-dim normalized speaker embeddings are stored.
- All storage paths are owner-only (`codyt:users`), enforced by systemd `ReadWritePaths` and `tmpfiles.rules`.
- Biometric data never leaves server storage and never enters repo output.

## GPU phase locking

Only one model is resident on the GPU at a time. The transcription pipeline cycles through: ASR → unload → alignment → unload → diarization → unload. The embedding extractor runs after all pipeline phases have released the GPU. A threading lock enforces one-job concurrency for transcription; the embedding extractor has its own GPU lock for concurrent enrollment/cache builds.

## Launch wiring

Launched by `hosts/beast/models.nix` as a llama-swap upstream:

```
PYTHONPATH=<repo>/modules/services/llama-swap \
python3 -m diarization.server \
  --host 127.0.0.1 --port $PORT \
  --model-id whisper-diarization \
  --device cuda --compute-type float16 \
  --download-root /var/cache/llama-swap/whisperx \
  --enrollment-dir /var/lib/llama-swap/diarization/enrollment \
  --hf-token-path <sops-managed>
```

The `PYTHONPATH` points at the `llama-swap/` directory so `diarization` resolves as a package. The `diarization-server.py` alongside this directory is a compatibility launcher that re-exports the package for test imports and also supports direct execution (`python diarization-server.py`); the Nix wiring invokes `python -m diarization.server` directly.

## Package layout

```
diarization/
  __init__.py      # Package exports
  embeddings.py    # EmbeddingExtractor, ShortSegmentSkipped
  enrollment.py    # EnrollmentStore, MIN_ENROLLMENT_SAMPLES
  cache.py         # EmbeddingCache
  identity.py      # cosine_similarity
  models.py        # ModelManager, _ModelPhase, BusyError
  server.py        # FastAPI app, routes, CLI, main()
  README.md        # This file
```
