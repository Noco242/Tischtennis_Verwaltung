from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from ..models.enums import ZusageStatus


class SpielCreate(BaseModel):
    mannschaft_id: int
    gegner: str
    ist_heimspiel: bool = True
    termin: datetime
    ort: Optional[str] = None
    externe_id: Optional[str] = None


class SpielUpdate(BaseModel):
    gegner: Optional[str] = None
    ist_heimspiel: Optional[bool] = None
    termin: Optional[datetime] = None
    ort: Optional[str] = None
    notiz: Optional[str] = None


class SpielRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    mannschaft_id: int
    gegner: str
    ist_heimspiel: bool
    termin: datetime
    ort: Optional[str]
    treffpunkt_ort: Optional[str]
    treffpunkt_zeit: Optional[datetime]
    notiz: Optional[str]
    aufstellung_freigegeben: bool


class TreffpunktUpdate(BaseModel):
    treffpunkt_ort: Optional[str] = None
    treffpunkt_zeit: Optional[datetime] = None
    notiz: Optional[str] = None


class AufstellungEintrag(BaseModel):
    position: int
    spieler_id: int
    ist_ersatz: bool = False


class AufstellungUpdate(BaseModel):
    eintraege: list[AufstellungEintrag]
    freigeben: bool = False


class AufstellungValidationResult(BaseModel):
    ok: bool
    warnungen: list[str] = []
    fehler: list[str] = []


class ZusageUpdate(BaseModel):
    status: ZusageStatus
    kommentar: Optional[str] = None


class ZusageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    spiel_id: int
    spieler_id: int
    status: ZusageStatus
    kommentar: Optional[str]
    geaendert_am: datetime


class PinZusageRequest(BaseModel):
    pin: str
    spieler_id: int
    status: ZusageStatus


class AufstellungEintragRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    position: int
    spieler_id: int
    ist_ersatz: bool


class SpielDetailRead(SpielRead):
    aufstellung: list[AufstellungEintragRead] = []
    zusagen: list[ZusageRead] = []


class ErsatzanfrageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    spiel_id: int
    spieler_id: int
    position: int
    status: ZusageStatus
    erstellt_am: datetime
