"""Health and model-listing routes for the diarization server."""

from fastapi import FastAPI


def register_health_routes(app: FastAPI) -> None:
    """Attach the root, health, and model-list endpoints."""

    @app.get("/")
    async def root():
        return {
            "status": "ok",
            "model": app.state.model_id,
            "device": app.state.device,
        }

    @app.get("/health")
    @app.get("/v1/health")
    async def health():
        return {"status": "ok", "device": app.state.device}

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
