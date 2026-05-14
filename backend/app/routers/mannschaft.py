# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_spieler, require_admin
from ..models import Mannschaft, MannschaftsMitglied, Rolle, Spieler
from ..schemas import (
    MannschaftCreate,
    MannschaftRead,
    MannschaftUpdate,
    MitgliedCreate,
    MitgliedRead,
)


router = APIRouter(prefix="/mannschaften", tags=["mannschaften"])


@router.get("", response_model=list[MannschaftRead])
def liste(db: Session = Depends(get_db), _: Spieler = Depends(get_current_spieler)) -> list[Mannschaft]:
    return db.query(Mannschaft).order_by(Mannschaft.rang).all()


@router.post("", response_model=MannschaftRead, status_code=status.HTTP_201_CREATED)
def anlegen(
    payload: MannschaftCreate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> Mannschaft:
    mannschaft = Mannschaft(**payload.model_dump())
    db.add(mannschaft)
    db.commit()
    db.refresh(mannschaft)
    if mannschaft.fuehrer_id:
        fuehrer = db.get(Spieler, mannschaft.fuehrer_id)
        if fuehrer and fuehrer.rolle == Rolle.SPIELER:
            fuehrer.rolle = Rolle.MANNSCHAFTSFUEHRER
            db.commit()
    return mannschaft


@router.get("/{mannschaft_id}", response_model=MannschaftRead)
def detail(
    mannschaft_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> Mannschaft:
    mannschaft = db.get(Mannschaft, mannschaft_id)
    if not mannschaft:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    return mannschaft


@router.patch("/{mannschaft_id}", response_model=MannschaftRead)
def bearbeiten(
    mannschaft_id: int,
    payload: MannschaftUpdate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> Mannschaft:
    mannschaft = db.get(Mannschaft, mannschaft_id)
    if not mannschaft:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(mannschaft, field, value)
    db.commit()
    db.refresh(mannschaft)
    return mannschaft


@router.get("/{mannschaft_id}/mitglieder", response_model=list[MitgliedRead])
def mitglieder(
    mannschaft_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> list[MannschaftsMitglied]:
    return (
        db.query(MannschaftsMitglied)
        .filter(MannschaftsMitglied.mannschaft_id == mannschaft_id)
        .order_by(MannschaftsMitglied.standardposition.is_(None), MannschaftsMitglied.standardposition)
        .all()
    )


@router.post("/{mannschaft_id}/mitglieder", response_model=MitgliedRead, status_code=status.HTTP_201_CREATED)
def mitglied_hinzufuegen(
    mannschaft_id: int,
    payload: MitgliedCreate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> MannschaftsMitglied:
    mannschaft = db.get(Mannschaft, mannschaft_id)
    if not mannschaft:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Mannschaft nicht gefunden")
    if not db.get(Spieler, payload.spieler_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Spieler nicht gefunden")
    existing = (
        db.query(MannschaftsMitglied)
        .filter(
            MannschaftsMitglied.mannschaft_id == mannschaft_id,
            MannschaftsMitglied.spieler_id == payload.spieler_id,
        )
        .first()
    )
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, "Spieler ist bereits Mitglied")
    mitglied = MannschaftsMitglied(mannschaft_id=mannschaft_id, **payload.model_dump())
    db.add(mitglied)
    db.commit()
    db.refresh(mitglied)
    return mitglied


@router.delete(
    "/{mannschaft_id}/mitglieder/{spieler_id}", status_code=status.HTTP_204_NO_CONTENT
)
def mitglied_entfernen(
    mannschaft_id: int,
    spieler_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> None:
    mitglied = (
        db.query(MannschaftsMitglied)
        .filter(
            MannschaftsMitglied.mannschaft_id == mannschaft_id,
            MannschaftsMitglied.spieler_id == spieler_id,
        )
        .first()
    )
    if not mitglied:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Mitgliedschaft nicht gefunden")
    db.delete(mitglied)
    db.commit()
