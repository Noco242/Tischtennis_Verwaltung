# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_spieler, require_admin
from ..models import Spieler, Rolle
from ..schemas import SpielerCreate, SpielerRead, SpielerUpdate, SpielerSelfUpdate
from ..security import hash_password


router = APIRouter(prefix="/spieler", tags=["spieler"])


@router.get("", response_model=list[SpielerRead])
def liste(
    db: Session = Depends(get_db),
    _: Spieler = Depends(get_current_spieler),
) -> list[Spieler]:
    return db.query(Spieler).order_by(Spieler.nachname, Spieler.vorname).all()


@router.post("", response_model=SpielerRead, status_code=status.HTTP_201_CREATED)
def anlegen(
    payload: SpielerCreate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> Spieler:
    if db.query(Spieler).filter(Spieler.email == payload.email).first():
        raise HTTPException(status.HTTP_409_CONFLICT, "E-Mail bereits vorhanden")
    spieler = Spieler(
        vorname=payload.vorname,
        nachname=payload.nachname,
        email=payload.email,
        telefon=payload.telefon,
        ttr=payload.ttr,
        jugend=payload.jugend,
        rolle=payload.rolle,
        passwort_hash=hash_password(payload.passwort),
    )
    db.add(spieler)
    db.commit()
    db.refresh(spieler)
    return spieler


@router.get("/{spieler_id}", response_model=SpielerRead)
def detail(
    spieler_id: int,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Spieler:
    # DSGVO: Telefonnummern nur intern - hier alle innerhalb des Vereins sichtbar.
    spieler = db.get(Spieler, spieler_id)
    if not spieler:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    return spieler


@router.patch("/{spieler_id}", response_model=SpielerRead)
def bearbeiten(
    spieler_id: int,
    payload: SpielerUpdate,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> Spieler:
    spieler = db.get(Spieler, spieler_id)
    if not spieler:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(spieler, field, value)
    db.commit()
    db.refresh(spieler)
    return spieler


@router.patch("/me/profil", response_model=SpielerRead)
def eigenes_profil(
    payload: SpielerSelfUpdate,
    db: Session = Depends(get_db),
    current: Spieler = Depends(get_current_spieler),
) -> Spieler:
    if payload.telefon is not None:
        current.telefon = payload.telefon
    if payload.passwort:
        current.passwort_hash = hash_password(payload.passwort)
    db.commit()
    db.refresh(current)
    return current


@router.delete("/{spieler_id}", status_code=status.HTTP_204_NO_CONTENT)
def loeschen(
    spieler_id: int,
    db: Session = Depends(get_db),
    _: Spieler = Depends(require_admin),
) -> None:
    spieler = db.get(Spieler, spieler_id)
    if not spieler:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nicht gefunden")
    db.delete(spieler)
    db.commit()
