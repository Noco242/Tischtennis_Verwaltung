# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from fastapi import APIRouter, Body, Depends, HTTPException, Path, Response, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_spieler, require_admin
from ..models import Spieler
from ..services.clicktt_import import importiere_spiele, spielplan_url
from ..services.ical_feed import ical_fuer_spieler


router = APIRouter(tags=["integrationen"])


@router.post("/import/clicktt/{mannschaft_id}")
def import_clicktt(
    mannschaft_id: int = Path(...),
    spiele: list[dict] = Body(...),
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> dict:
    """Importiert Spieldaten fuer eine Mannschaft.

    Erwartet eine bereits aufbereitete Liste (siehe services.clicktt_import).
    Ein echter Crawler fuer mytischtennis.de folgt in einer spaeteren Iteration.
    """
    try:
        neu, aktualisiert = importiere_spiele(db, mannschaft_id, spiele)
    except ValueError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    return {"neu": neu, "aktualisiert": aktualisiert}


@router.get("/ical/{token}.ics")
def ical_feed(token: str, db: Session = Depends(get_db)) -> Response:
    """Dynamischer iCal-Feed.

    Im MVP ist `token` schlicht die Spieler-ID. In Produktion sollte stattdessen
    ein eigener, nicht-erratbarer Token pro Spieler generiert werden.
    """
    try:
        spieler_id = int(token)
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Feed nicht gefunden")
    spieler = db.get(Spieler, spieler_id)
    if not spieler:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Feed nicht gefunden")
    body = ical_fuer_spieler(db, spieler)
    return Response(content=body, media_type="text/calendar; charset=utf-8")


@router.get("/me/ical-url")
def eigene_ical_url(current: Spieler = Depends(get_current_spieler)) -> dict:
    return {"url": f"/ical/{current.id}.ics"}


@router.get("/clicktt/spielplan-url")
def clicktt_spielplan_url(
    verband: str = "BaTTV",
    saison: str = "25--26",
    verein_id: int = 1012,
    vereinsname: str = "FC 1932 e.V. Külsheim",
    _: Spieler = Depends(get_current_spieler),
) -> dict:
    """Liefert den click-TT-Spielplan-Link, fuer FC Kuelsheim Saison 2025/26 als Default."""
    return {"url": spielplan_url(verband, saison, verein_id, vereinsname)}
