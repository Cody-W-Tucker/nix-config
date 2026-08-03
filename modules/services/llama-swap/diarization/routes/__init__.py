"""Route subpackage for the diarization FastAPI application.

Each module exposes a ``register_*_routes(app)`` function that attaches
its endpoints to the FastAPI instance. Shared state is carried on
``app.state`` so handlers can reach the model manager, enrollment store,
embedding extractor, and cache without closing over construction-time
locals.
"""
