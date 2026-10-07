"""LifeStep API. Run from backend/:  uvicorn app.main:app --reload --port 8000"""
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from . import config
from .routers.api import router

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
log = logging.getLogger("lifestep")

app = FastAPI(title="LifeStep API", version="0.1.0")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)
app.include_router(router)


@app.on_event("startup")
def _startup() -> None:
    log.info("AI mode: %s (model %s) | store: %s | auth: %s",
             config.AI_MODE, config.CLAUDE_MODEL, config.STORE, config.AUTH)
    if config.STORE == "local":
        from .store import get_repository
        from seed.seed_demo import seed

        if get_repository().load(config.DEMO_USER_ID).plan is None:
            log.info("Seeding demo patient...")
            seed()


# Serve the built Flutter web app (flutter build web) from the same origin, if present.
if config.WEB_BUILD_DIR.exists():
    app.mount("/", StaticFiles(directory=config.WEB_BUILD_DIR, html=True), name="web")
