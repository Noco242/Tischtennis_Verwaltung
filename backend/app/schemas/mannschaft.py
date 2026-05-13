# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from typing import Optional

from pydantic import BaseModel, ConfigDict


class MannschaftCreate(BaseModel):
    name: str
    rang: int
    spielklasse: Optional[str] = None
    fuehrer_id: Optional[int] = None


class MannschaftUpdate(BaseModel):
    name: Optional[str] = None
    rang: Optional[int] = None
    spielklasse: Optional[str] = None
    fuehrer_id: Optional[int] = None


class MitgliedCreate(BaseModel):
    spieler_id: int
    standardposition: Optional[int] = None
    ist_stammspieler: bool = True
    meldenummer: Optional[str] = None


class MitgliedRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    spieler_id: int
    standardposition: Optional[int]
    ist_stammspieler: bool
    meldenummer: Optional[str] = None


class MannschaftRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    rang: int
    spielklasse: Optional[str]
    fuehrer_id: Optional[int]
