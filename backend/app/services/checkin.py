# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import asyncio
import logging
import socket
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

import httpx

from ..config import Settings
from ..legal import COPYRIGHT_NOTICE, LICENSE_NOTICE


logger = logging.getLogger(__name__)


def _truncate(value: object, limit: int = 1024) -> str:
    text = str(value)
    return text if len(text) <= limit else f"{text[: limit - 3]}..."


def format_runtime(seconds: int) -> str:
    seconds = max(0, seconds)
    hours, remainder = divmod(seconds, 3600)
    minutes, rest = divmod(remainder, 60)
    parts = []
    if hours:
        parts.append(f"{hours}h")
    if minutes or hours:
        parts.append(f"{minutes}m")
    parts.append(f"{rest}s")
    return " ".join(parts)


def get_server_ip_info() -> dict[str, Any]:
    hostname = socket.gethostname()
    local_ips: list[str] = []
    outbound_ip = None
    try:
        local_ips = sorted(set(socket.gethostbyname_ex(hostname)[2]))
    except OSError:
        logger.debug("Could not resolve host IPs.", exc_info=True)

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            outbound_ip = s.getsockname()[0]
    except OSError:
        logger.debug("Could not determine outbound IP.", exc_info=True)

    return {
        "hostname": hostname,
        "local_ips": local_ips,
        "outbound_ip": outbound_ip,
    }


def build_checkin_payload(
    settings: Settings,
    event: str = "startup",
    source: str = "backend",
    runtime_seconds: int | None = None,
    ip_info: dict[str, Any] | None = None,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "event": event,
        "source": source,
        "app": settings.app_name,
        "version": settings.app_version,
        "deployment_id": settings.deployment_id,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "copyright": COPYRIGHT_NOTICE,
        "license_notice": LICENSE_NOTICE,
    }
    if runtime_seconds is not None:
        payload["runtime_seconds"] = max(0, runtime_seconds)
        payload["runtime"] = format_runtime(runtime_seconds)
    if ip_info:
        payload["ip_info"] = ip_info
    if extra:
        payload.update({k: v for k, v in extra.items() if v is not None})
    return payload


def is_discord_webhook(url: str) -> bool:
    parsed = urlparse(url)
    return (
        parsed.scheme == "https"
        and parsed.netloc.lower()
        in {"discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com"}
        and parsed.path.startswith("/api/webhooks/")
    )


def build_discord_payload(checkin_payload: dict[str, Any]) -> dict[str, Any]:
    fields = [
        ("Event", checkin_payload["event"]),
        ("Quelle", checkin_payload.get("source", "backend")),
        ("App", checkin_payload["app"]),
        ("Version", checkin_payload["version"]),
        ("Deployment-ID", checkin_payload["deployment_id"]),
        ("Zeitpunkt UTC", checkin_payload["timestamp_utc"]),
    ]
    if "runtime" in checkin_payload:
        fields.append(("Laufzeit", checkin_payload["runtime"]))

    ip_info = checkin_payload.get("ip_info") or {}
    if ip_info.get("hostname"):
        fields.append(("Hostname", ip_info["hostname"]))
    if ip_info.get("outbound_ip"):
        fields.append(("Server-IP", ip_info["outbound_ip"]))
    if ip_info.get("local_ips"):
        fields.append(("Lokale IPs", ", ".join(ip_info["local_ips"])))
    if ip_info.get("client_ip"):
        fields.append(("Client-IP", ip_info["client_ip"]))
    if ip_info.get("forwarded_for"):
        fields.append(("Forwarded-For", ip_info["forwarded_for"]))
    if checkin_payload.get("page_url"):
        fields.append(("Frontend-URL", checkin_payload["page_url"]))
    if checkin_payload.get("user_agent"):
        fields.append(("User-Agent", checkin_payload["user_agent"]))

    title = (
        "Frontend-Heartbeat"
        if checkin_payload.get("source") == "frontend"
        else "Backend-Heartbeat"
    )
    return {
        "username": "TT-Match-Manager Check-in",
        "content": "TT-Match-Manager Deployment-Check-in",
        "allowed_mentions": {"parse": []},
        "embeds": [
            {
                "title": title,
                "description": _truncate(checkin_payload["license_notice"], 4096),
                "color": 3447003,
                "fields": [
                    {"name": name, "value": _truncate(value), "inline": True}
                    for name, value in fields[:25]
                ],
                "timestamp": checkin_payload["timestamp_utc"],
                "footer": {"text": _truncate(checkin_payload["copyright"], 2048)},
            }
        ],
    }


async def send_deployment_checkin(
    settings: Settings,
    event: str = "startup",
    source: str = "backend",
    runtime_seconds: int | None = None,
    ip_info: dict[str, Any] | None = None,
    extra: dict[str, Any] | None = None,
) -> bool:
    if not settings.deployment_checkin_enabled:
        logger.info("Deployment check-in is disabled.")
        return False
    if not settings.deployment_checkin_url:
        logger.warning("Deployment check-in is enabled but no URL is configured.")
        return False

    payload = build_checkin_payload(
        settings,
        event=event,
        source=source,
        runtime_seconds=runtime_seconds,
        ip_info=ip_info,
        extra=extra,
    )
    request_payload = (
        build_discord_payload(payload)
        if is_discord_webhook(settings.deployment_checkin_url)
        else payload
    )
    try:
        async with httpx.AsyncClient(
            timeout=settings.deployment_checkin_timeout_seconds,
            follow_redirects=True,
        ) as client:
            response = await client.post(
                settings.deployment_checkin_url,
                json=request_payload,
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        logger.warning("Deployment check-in failed: %s", exc)
        return False

    logger.info("Deployment check-in sent for deployment %s.", settings.deployment_id)
    return True


async def run_periodic_backend_checkins(
    settings: Settings,
    started_at_utc: datetime,
) -> None:
    if not settings.deployment_checkin_enabled or not settings.deployment_checkin_url:
        return
    if settings.deployment_checkin_interval_seconds <= 0:
        return

    while True:
        await asyncio.sleep(settings.deployment_checkin_interval_seconds)
        runtime_seconds = int(
            (datetime.now(timezone.utc) - started_at_utc).total_seconds()
        )
        await send_deployment_checkin(
            settings,
            event="heartbeat",
            source="backend",
            runtime_seconds=runtime_seconds,
            ip_info=get_server_ip_info(),
        )
