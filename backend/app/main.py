# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import asyncio
import contextlib
import logging
from datetime import datetime, timezone

from fastapi import BackgroundTasks, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .config import settings
from .database import Base, engine
from .legal import COPYRIGHT_HOLDERS, COPYRIGHT_NOTICE, LICENSE_NOTICE
from .routers import auth, spieler, mannschaft, spiel, integration
from .services.checkin import (
    get_server_ip_info,
    run_periodic_backend_checkins,
    send_deployment_checkin,
)


logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("httpx").setLevel(logging.WARNING)


class FrontendCheckinRequest(BaseModel):
    event: str = Field(default="heartbeat", max_length=64)
    runtime_seconds: int = Field(default=0, ge=0)
    page_url: str | None = Field(default=None, max_length=2048)
    public_ip: str | None = Field(default=None, max_length=128)


def create_app() -> FastAPI:
    Base.metadata.create_all(bind=engine)

    app = FastAPI(title=settings.app_name, version=settings.app_version)
    app.state.started_at_utc = datetime.now(timezone.utc)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(spieler.router)
    app.include_router(mannschaft.router)
    app.include_router(spiel.router)
    app.include_router(integration.router)

    @app.get("/health", tags=["meta"])
    def health() -> dict:
        return {"status": "ok", "app": settings.app_name}

    @app.get("/meta/copyright", tags=["meta"])
    def copyright_info() -> dict:
        return {
            "holders": COPYRIGHT_HOLDERS,
            "copyright": COPYRIGHT_NOTICE,
            "license_notice": LICENSE_NOTICE,
            "deployment_checkin_enabled": settings.deployment_checkin_enabled,
        }

    @app.post("/meta/frontend-checkin", tags=["meta"])
    def frontend_checkin(
        payload: FrontendCheckinRequest,
        request: Request,
        background_tasks: BackgroundTasks,
    ) -> dict:
        client_ip = request.client.host if request.client else None
        forwarded_for = request.headers.get("x-forwarded-for")
        user_agent = request.headers.get("user-agent")
        ip_info = {
            "client_ip": client_ip,
            "forwarded_for": forwarded_for,
            "public_ip": payload.public_ip,
        }
        background_tasks.add_task(
            send_deployment_checkin,
            settings,
            event=payload.event,
            source="frontend",
            runtime_seconds=payload.runtime_seconds,
            ip_info=ip_info,
            extra={
                "page_url": payload.page_url,
                "user_agent": user_agent,
            },
        )
        return {"status": "queued"}

    async def startup_checkin() -> None:
        await send_deployment_checkin(
            settings,
            event="startup",
            source="backend",
            runtime_seconds=0,
            ip_info=get_server_ip_info(),
        )
        app.state.deployment_checkin_task = asyncio.create_task(
            run_periodic_backend_checkins(settings, app.state.started_at_utc)
        )

    async def shutdown_checkin() -> None:
        task = getattr(app.state, "deployment_checkin_task", None)
        if task:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

    app.router.add_event_handler("startup", startup_checkin)
    app.router.add_event_handler("shutdown", shutdown_checkin)

    return app


app = create_app()
