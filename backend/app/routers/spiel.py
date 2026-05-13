# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_spieler, require_admin
from ..models import (
    Aufstellung,
    Ersatzanfrage,
    Mannschaft,
    MannschaftsMitglied,
    Rolle,
    Spieler,
    Spiel,
    Zusage,
    ZusageStatus,
)
from ..schemas import (
    AufstellungUpdate,
    AufstellungValidationResult,
    ErsatzanfrageRead,
    PinZusageRequest,
    SpielCreate,
    SpielDetailRead,
    SpielRead,
    SpielUpdate,
    TreffpunktUpdate,
    ZusageRead,
    ZusageUpdate,
)
from ..services.aufstellung import naechster_ersatzspieler, validiere_aufstellung
from ..services.notifications import Nachricht, sende, sende_an_viele


router = APIRouter(prefix="/spiele", tags=["spiele"])


def _ist_mannschaftsfuehrer_von(spieler: Spieler, mannschaft: Mannschaft) -> bool:
    return spieler.rolle == Rolle.ADMIN or mannschaft.fuehrer_id == spieler.id


def _heimspiel_kollisionen(db: Session, spiel: Spiel) -> list[Spiel]:
    """Pruefe, ob am selben Tag eine andere Heimmannschaft spielt."""
    if not spiel.ist_heimspiel:
        return []
    tag_start = spiel.termin.replace(hour=0, minute=0, second=0, microsecond=0)
    tag_ende = tag_start + timedelta(days=1)
    return (
        db.query(Spiel)
        .filter(
            Spiel.id != spiel.id,
            Spiel.ist_heimspiel.is_(True),
            Spiel.termin >= tag_start,
            Spiel.termin < tag_ende,
        )
        .all()
    )


@router.get("", response_model=list[SpielDetailRead])
def liste(
    mannschaft_id: Optional[int] = Query(default=None),
    ab: Optional[datetime] = Query(default=None),
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> list[Spiel]:
    query = db.query(Spiel)
    if mannschaft_id is not None:
        query = query.filter(Spiel.mannschaft_id == mannschaft_id)
    if ab is not None:
        query = query.filter(Spiel.termin >= ab)
    return query.order_by(Spiel.termin).all()


@router.get("/meine", response_model=list[SpielDetailRead])
def eigene_spiele(
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> list[Spiel]:
    """Spiele aller Mannschaften, in denen der Spieler Mitglied ist + Aufstellungen."""
    mannschaft_ids = [
        m.mannschaft_id
        for m in db.query(MannschaftsMitglied).filter(MannschaftsMitglied.spieler_id == current.id).all()
    ]
    aufstellung_spiel_ids = [
        a.spiel_id
        for a in db.query(Aufstellung).filter(Aufstellung.spieler_id == current.id).all()
    ]
    query = db.query(Spiel)
    if mannschaft_ids or aufstellung_spiel_ids:
        query = query.filter(
            (Spiel.mannschaft_id.in_(mannschaft_ids))
            | (Spiel.id.in_(aufstellung_spiel_ids))
        )
    else:
        return []
    return query.order_by(Spiel.termin).all()


@router.post("", response_model=SpielRead, status_code=status.HTTP_201_CREATED)
def anlegen(
    payload: SpielCreate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> Spiel:
    if not db.get(Mannschaft, payload.mannschaft_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Mannschaft nicht gefunden")
    spiel = Spiel(**payload.model_dump(), pin=secrets.token_urlsafe(6)[:8])
    db.add(spiel)
    db.commit()
    db.refresh(spiel)

    kollisionen = _heimspiel_kollisionen(db, spiel)
    if kollisionen:
        ids = ", ".join(str(k.id) for k in kollisionen)
        spiel.notiz = (spiel.notiz or "") + f" [Kollision Heimspiel mit Spiel(en) {ids}]"
        db.commit()
    return spiel


@router.get("/{spiel_id}", response_model=SpielDetailRead)
def detail(
    spiel_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> Spiel:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    return spiel


@router.patch("/{spiel_id}", response_model=SpielRead)
def bearbeiten(
    spiel_id: int,
    payload: SpielUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Spiel:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    if not _ist_mannschaftsfuehrer_von(current, spiel.mannschaft):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Nur Mannschaftsfuehrer/Admin")
    aenderungen = payload.model_dump(exclude_unset=True)
    terminverschoben = "termin" in aenderungen and aenderungen["termin"] != spiel.termin
    for field, value in aenderungen.items():
        setattr(spiel, field, value)
    db.commit()
    db.refresh(spiel)

    if terminverschoben:
        # Benachrichtige alle Spieler, die zugesagt haben oder aufgestellt sind.
        ids = {a.spieler_id for a in spiel.aufstellung} | {
            z.spieler_id for z in spiel.zusagen if z.status == ZusageStatus.ZUGESAGT
        }
        empfaenger = db.query(Spieler).filter(Spieler.id.in_(ids)).all() if ids else []
        sende_an_viele(
            Nachricht(
                empfaenger=e,
                betreff="Spiel verlegt",
                text=f"Das Spiel gegen {spiel.gegner} wurde auf {spiel.termin:%d.%m.%Y %H:%M} verschoben.",
            )
            for e in empfaenger
        )
    return spiel


@router.post("/{spiel_id}/treffpunkt", response_model=SpielRead)
def treffpunkt_setzen(
    spiel_id: int,
    payload: TreffpunktUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Spiel:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    if not _ist_mannschaftsfuehrer_von(current, spiel.mannschaft):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Nur Mannschaftsfuehrer/Admin")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(spiel, field, value)
    db.commit()
    db.refresh(spiel)
    return spiel


# ----------------- Zusagen -----------------


@router.post("/{spiel_id}/zusage", response_model=ZusageRead)
def zusage_aktualisieren(
    spiel_id: int,
    payload: ZusageUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Zusage:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Spiel nicht gefunden")
    return _setze_zusage(db, spiel, current.id, payload.status, payload.kommentar)


@router.post("/{spiel_id}/zusage-pin", response_model=ZusageRead)
def zusage_via_pin(
    spiel_id: int,
    payload: PinZusageRequest,
    db: Session = Depends(get_db),
) -> Zusage:
    """Schnellzusage ohne Voll-Login (FA 2.4 Spiel-PIN)."""
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Spiel nicht gefunden")
    if not spiel.pin or spiel.pin != payload.pin:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "PIN ungueltig")
    if not db.get(Spieler, payload.spieler_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Spieler nicht gefunden")
    return _setze_zusage(db, spiel, payload.spieler_id, payload.status, None)


def _setze_zusage(
    db: Session, spiel: Spiel, spieler_id: int, neuer_status: ZusageStatus, kommentar: Optional[str]
) -> Zusage:
    zusage = (
        db.query(Zusage)
        .filter(Zusage.spiel_id == spiel.id, Zusage.spieler_id == spieler_id)
        .first()
    )
    war_zugesagt = zusage and zusage.status == ZusageStatus.ZUGESAGT
    if zusage:
        zusage.status = neuer_status
        zusage.kommentar = kommentar
        zusage.geaendert_am = datetime.utcnow()
    else:
        zusage = Zusage(
            spiel_id=spiel.id,
            spieler_id=spieler_id,
            status=neuer_status,
            kommentar=kommentar,
        )
        db.add(zusage)
    db.commit()
    db.refresh(zusage)

    # Wenn ein aufgestellter Spieler abgesagt hat -> Ersatz-Workflow starten.
    aufgestellt = (
        db.query(Aufstellung)
        .filter(Aufstellung.spiel_id == spiel.id, Aufstellung.spieler_id == spieler_id)
        .first()
    )
    if neuer_status == ZusageStatus.ABGESAGT and aufgestellt and war_zugesagt is not False:
        _ersatz_workflow(db, spiel, aufgestellt.position)

    return zusage


def _ersatz_workflow(db: Session, spiel: Spiel, position: int) -> None:
    """Sucht den naechsten Ersatzspieler und legt eine Anfrage an."""
    naechster = naechster_ersatzspieler(db, spiel, position)
    if not naechster:
        if spiel.mannschaft.fuehrer:
            sende(
                Nachricht(
                    empfaenger=spiel.mannschaft.fuehrer,
                    betreff="Kein Ersatzspieler verfuegbar",
                    text=(
                        f"Fuer das Spiel gegen {spiel.gegner} konnte kein geeigneter "
                        f"Ersatzspieler fuer Position {position} gefunden werden."
                    ),
                )
            )
        return

    anfrage = Ersatzanfrage(
        spiel_id=spiel.id,
        spieler_id=naechster.id,
        position=position,
    )
    db.add(anfrage)
    db.commit()

    sende(
        Nachricht(
            empfaenger=naechster,
            betreff="Ersatzspieler-Anfrage",
            text=(
                f"Hallo {naechster.vorname}, fuer das Spiel der {spiel.mannschaft.name} gegen "
                f"{spiel.gegner} am {spiel.termin:%d.%m.%Y %H:%M} (Position {position}) wird "
                f"ein Ersatzspieler benoetigt. Bitte zeitnah ueber die App zu- oder absagen."
            ),
        )
    )


@router.get("/{spiel_id}/zusagen", response_model=list[ZusageRead])
def zusagen_liste(
    spiel_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> list[Zusage]:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    return spiel.zusagen


# ----------------- Aufstellung -----------------


@router.post("/{spiel_id}/aufstellung/validieren", response_model=AufstellungValidationResult)
def aufstellung_validieren(
    spiel_id: int,
    payload: AufstellungUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> AufstellungValidationResult:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    if not _ist_mannschaftsfuehrer_von(current, spiel.mannschaft):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Nur Mannschaftsfuehrer/Admin")
    warnungen, fehler = validiere_aufstellung(
        db, spiel, [(e.position, e.spieler_id, e.ist_ersatz) for e in payload.eintraege]
    )
    return AufstellungValidationResult(ok=not fehler, warnungen=warnungen, fehler=fehler)


@router.put("/{spiel_id}/aufstellung", response_model=SpielDetailRead)
def aufstellung_setzen(
    spiel_id: int,
    payload: AufstellungUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Spiel:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    if not _ist_mannschaftsfuehrer_von(current, spiel.mannschaft):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Nur Mannschaftsfuehrer/Admin")

    warnungen, fehler = validiere_aufstellung(
        db, spiel, [(e.position, e.spieler_id, e.ist_ersatz) for e in payload.eintraege]
    )
    if fehler:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"fehler": fehler, "warnungen": warnungen},
        )

    db.query(Aufstellung).filter(Aufstellung.spiel_id == spiel_id).delete()
    for eintrag in payload.eintraege:
        db.add(
            Aufstellung(
                spiel_id=spiel_id,
                position=eintrag.position,
                spieler_id=eintrag.spieler_id,
                ist_ersatz=eintrag.ist_ersatz,
            )
        )
    spiel.aufstellung_freigegeben = payload.freigeben
    db.commit()
    db.refresh(spiel)

    if payload.freigeben:
        aufgestellte_ids = [e.spieler_id for e in payload.eintraege]
        empfaenger = db.query(Spieler).filter(Spieler.id.in_(aufgestellte_ids)).all()
        sende_an_viele(
            Nachricht(
                empfaenger=s,
                betreff="Aufstellung freigegeben",
                text=(
                    f"Du bist fuer das Spiel der {spiel.mannschaft.name} gegen {spiel.gegner} "
                    f"am {spiel.termin:%d.%m.%Y %H:%M} aufgestellt. Bitte rechtzeitig zu-/absagen."
                ),
            )
            for s in empfaenger
        )
    return spiel


# ----------------- Ersatzanfragen -----------------


@router.get("/{spiel_id}/ersatzanfragen", response_model=list[ErsatzanfrageRead])
def ersatzanfragen_liste(
    spiel_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> list[Ersatzanfrage]:
    return db.query(Ersatzanfrage).filter(Ersatzanfrage.spiel_id == spiel_id).all()


@router.post("/{spiel_id}/ersatz-naechster", response_model=Optional[ErsatzanfrageRead])
def ersatz_manuell_anfordern(
    spiel_id: int,
    position: int = Body(embed=True),
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Optional[Ersatzanfrage]:
    spiel = db.get(Spiel, spiel_id)
    if not spiel:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    if not _ist_mannschaftsfuehrer_von(current, spiel.mannschaft):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Nur Mannschaftsfuehrer/Admin")
    _ersatz_workflow(db, spiel, position)
    return (
        db.query(Ersatzanfrage)
        .filter(Ersatzanfrage.spiel_id == spiel_id)
        .order_by(Ersatzanfrage.id.desc())
        .first()
    )
