# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from app.config import Settings
from app.legal import COPYRIGHT_NOTICE
from app.services.checkin import (
    build_checkin_payload,
    build_discord_payload,
    format_runtime,
    is_discord_webhook,
)


def test_build_checkin_payload_contains_copyright_notice():
    settings = Settings(
        app_name="TT-Match-Manager",
        app_version="0.1.0",
        deployment_id="test-deployment",
    )

    payload = build_checkin_payload(settings)

    assert payload["event"] == "startup"
    assert payload["app"] == "TT-Match-Manager"
    assert payload["deployment_id"] == "test-deployment"
    assert payload["copyright"] == COPYRIGHT_NOTICE
    assert "timestamp_utc" in payload


def test_checkin_payload_contains_runtime_and_ip_info():
    settings = Settings(deployment_id="test-deployment")

    payload = build_checkin_payload(
        settings,
        event="heartbeat",
        source="frontend",
        runtime_seconds=7205,
        ip_info={"client_ip": "127.0.0.1", "public_ip": "203.0.113.10"},
        extra={"page_url": "http://127.0.0.1:8080"},
    )

    assert payload["source"] == "frontend"
    assert payload["runtime_seconds"] == 7205
    assert payload["runtime"] == "2h 0m 5s"
    assert payload["ip_info"]["client_ip"] == "127.0.0.1"
    assert payload["ip_info"]["public_ip"] == "203.0.113.10"
    assert payload["page_url"] == "http://127.0.0.1:8080"


def test_format_runtime():
    assert format_runtime(0) == "0s"
    assert format_runtime(65) == "1m 5s"
    assert format_runtime(7200) == "2h 0m 0s"


def test_discord_webhook_url_is_detected():
    assert is_discord_webhook("https://discord.com/api/webhooks/1/token")
    assert is_discord_webhook("https://discordapp.com/api/webhooks/1/token")
    assert not is_discord_webhook("https://example.org/api/webhooks/1/token")


def test_build_discord_payload_contains_message_content():
    settings = Settings(deployment_id="test-deployment")
    checkin_payload = build_checkin_payload(settings)

    payload = build_discord_payload(checkin_payload)

    assert payload["content"] == "TT-Match-Manager Deployment-Check-in"
    assert payload["allowed_mentions"] == {"parse": []}
    fields = {field["name"]: field["value"] for field in payload["embeds"][0]["fields"]}
    assert fields["Deployment-ID"] == "test-deployment"


def test_frontend_checkin_endpoint_accepts_runtime_and_ip(client):
    r = client.post(
        "/meta/frontend-checkin",
        json={
            "event": "heartbeat",
            "runtime_seconds": 7200,
            "page_url": "http://127.0.0.1:8080",
            "public_ip": "203.0.113.10",
        },
    )

    assert r.status_code == 200, r.text
    assert r.json() == {"status": "queued"}
