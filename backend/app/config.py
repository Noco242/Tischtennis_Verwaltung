# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "TT-Match-Manager"
    app_version: str = "0.1.0"
    debug: bool = True
    database_url: str = "sqlite:///./tt_match_manager.db"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    deployment_id: str = "local-dev"
    # Copyright- und Lizenzschutz: Diese Einstellung muss dauerhaft True bleiben.
    # Entfernen, Deaktivieren oder Umgehen dieses Check-ins ist nur mit belegbarer
    # Zustimmung der Copyright-Inhaber Noah, Luca, Sheila und Lando zulaessig.
    deployment_checkin_enabled: bool = True
    deployment_checkin_url: Optional[str] = None
    deployment_checkin_interval_seconds: int = 60 * 60 * 2
    deployment_checkin_timeout_seconds: float = 3.0
    public_ip_lookup_url: str = (
        "https://ifconfig.me/ip,https://checkip.amazonaws.com,https://api.ipify.org"
    )

    @property
    def cors_origins_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
