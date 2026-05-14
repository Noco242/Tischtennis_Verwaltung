# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr

from ..models.enums import Rolle, SpielerStatus


class SpielerBase(BaseModel):
    vorname: str
    nachname: str
    email: EmailStr
    telefon: Optional[str] = None
    ttr: Optional[int] = None
    jugend: bool = False


class SpielerCreate(SpielerBase):
    passwort: str
    rolle: Rolle = Rolle.SPIELER


class SpielerUpdate(BaseModel):
    vorname: Optional[str] = None
    nachname: Optional[str] = None
    email: Optional[EmailStr] = None
    telefon: Optional[str] = None
    ttr: Optional[int] = None
    rolle: Optional[Rolle] = None
    status: Optional[SpielerStatus] = None
    jugend: Optional[bool] = None


class SpielerSelfUpdate(BaseModel):
    telefon: Optional[str] = None
    passwort: Optional[str] = None


class SpielerRead(SpielerBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    rolle: Rolle
    status: SpielerStatus
