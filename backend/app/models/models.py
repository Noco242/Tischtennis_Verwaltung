# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    String,
    Integer,
    Float,
    DateTime,
    ForeignKey,
    Enum as SAEnum,
    UniqueConstraint,
    Boolean,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base
from .enums import Rolle, SpielerStatus, ZusageStatus


class Spieler(Base):
    __tablename__ = "spieler"

    id: Mapped[int] = mapped_column(primary_key=True)
    vorname: Mapped[str] = mapped_column(String(80))
    nachname: Mapped[str] = mapped_column(String(80))
    email: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    telefon: Mapped[Optional[str]] = mapped_column(String(40), default=None)
    ttr: Mapped[Optional[int]] = mapped_column(Integer, default=None)
    status: Mapped[SpielerStatus] = mapped_column(SAEnum(SpielerStatus), default=SpielerStatus.AKTIV)
    rolle: Mapped[Rolle] = mapped_column(SAEnum(Rolle), default=Rolle.SPIELER)
    passwort_hash: Mapped[str] = mapped_column(String(255))
    jugend: Mapped[bool] = mapped_column(Boolean, default=False)
    erstellt_am: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    mitgliedschaften: Mapped[list["MannschaftsMitglied"]] = relationship(
        back_populates="spieler", cascade="all, delete-orphan"
    )
    zusagen: Mapped[list["Zusage"]] = relationship(back_populates="spieler", cascade="all, delete-orphan")

    @property
    def name(self) -> str:
        return f"{self.vorname} {self.nachname}"


class Mannschaft(Base):
    __tablename__ = "mannschaft"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    rang: Mapped[int] = mapped_column(Integer, index=True)
    spielklasse: Mapped[Optional[str]] = mapped_column(String(80), default=None)
    fuehrer_id: Mapped[Optional[int]] = mapped_column(ForeignKey("spieler.id"), default=None)

    fuehrer: Mapped[Optional["Spieler"]] = relationship(foreign_keys=[fuehrer_id])
    mitglieder: Mapped[list["MannschaftsMitglied"]] = relationship(
        back_populates="mannschaft", cascade="all, delete-orphan"
    )
    heimspiele: Mapped[list["Spiel"]] = relationship(
        back_populates="mannschaft", cascade="all, delete-orphan"
    )


class MannschaftsMitglied(Base):
    """Zuordnung Spieler -> Mannschaft.

    Ein Spieler kann in mehreren Mannschaften gleichzeitig eingetragen sein
    (Stammmeldung + Zweitspielrecht, z.B. gemeldet als "6.1" und zusaetzlich
    in der 5. Mannschaft einsetzbar). Genau eine Mitgliedschaft pro Spieler
    sollte `ist_stammspieler=True` haben.
    """

    __tablename__ = "mannschafts_mitglied"
    __table_args__ = (UniqueConstraint("spieler_id", "mannschaft_id", name="uq_spieler_mannschaft"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    spieler_id: Mapped[int] = mapped_column(ForeignKey("spieler.id"))
    mannschaft_id: Mapped[int] = mapped_column(ForeignKey("mannschaft.id"))
    standardposition: Mapped[Optional[int]] = mapped_column(Integer, default=None)
    ist_stammspieler: Mapped[bool] = mapped_column(Boolean, default=True)
    # offizielle Meldenummer (z.B. "6.1") - dient als Anker fuer Aufstiegs-Regel
    meldenummer: Mapped[Optional[str]] = mapped_column(String(16), default=None)

    spieler: Mapped["Spieler"] = relationship(back_populates="mitgliedschaften")
    mannschaft: Mapped["Mannschaft"] = relationship(back_populates="mitglieder")


class Spiel(Base):
    __tablename__ = "spiel"

    id: Mapped[int] = mapped_column(primary_key=True)
    mannschaft_id: Mapped[int] = mapped_column(ForeignKey("mannschaft.id"), index=True)
    gegner: Mapped[str] = mapped_column(String(160))
    ist_heimspiel: Mapped[bool] = mapped_column(Boolean, default=True)
    termin: Mapped[datetime] = mapped_column(DateTime, index=True)
    ort: Mapped[Optional[str]] = mapped_column(String(255), default=None)
    treffpunkt_ort: Mapped[Optional[str]] = mapped_column(String(255), default=None)
    treffpunkt_zeit: Mapped[Optional[datetime]] = mapped_column(DateTime, default=None)
    notiz: Mapped[Optional[str]] = mapped_column(String(500), default=None)
    aufstellung_freigegeben: Mapped[bool] = mapped_column(Boolean, default=False)
    pin: Mapped[Optional[str]] = mapped_column(String(12), default=None, index=True)
    externe_id: Mapped[Optional[str]] = mapped_column(String(64), default=None, index=True)

    mannschaft: Mapped["Mannschaft"] = relationship(back_populates="heimspiele")
    aufstellung: Mapped[list["Aufstellung"]] = relationship(
        back_populates="spiel", cascade="all, delete-orphan", order_by="Aufstellung.position"
    )
    zusagen: Mapped[list["Zusage"]] = relationship(back_populates="spiel", cascade="all, delete-orphan")
    ersatzanfragen: Mapped[list["Ersatzanfrage"]] = relationship(
        back_populates="spiel", cascade="all, delete-orphan"
    )


class Aufstellung(Base):
    __tablename__ = "aufstellung"
    __table_args__ = (UniqueConstraint("spiel_id", "position", name="uq_spiel_position"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    spiel_id: Mapped[int] = mapped_column(ForeignKey("spiel.id"))
    position: Mapped[int] = mapped_column(Integer)
    spieler_id: Mapped[int] = mapped_column(ForeignKey("spieler.id"))
    ist_ersatz: Mapped[bool] = mapped_column(Boolean, default=False)

    spiel: Mapped["Spiel"] = relationship(back_populates="aufstellung")
    spieler: Mapped["Spieler"] = relationship()


class Zusage(Base):
    __tablename__ = "zusage"
    __table_args__ = (UniqueConstraint("spiel_id", "spieler_id", name="uq_spiel_spieler_zusage"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    spiel_id: Mapped[int] = mapped_column(ForeignKey("spiel.id"))
    spieler_id: Mapped[int] = mapped_column(ForeignKey("spieler.id"))
    status: Mapped[ZusageStatus] = mapped_column(SAEnum(ZusageStatus), default=ZusageStatus.OFFEN)
    kommentar: Mapped[Optional[str]] = mapped_column(String(255), default=None)
    geaendert_am: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    spiel: Mapped["Spiel"] = relationship(back_populates="zusagen")
    spieler: Mapped["Spieler"] = relationship(back_populates="zusagen")


class Ersatzanfrage(Base):
    __tablename__ = "ersatzanfrage"

    id: Mapped[int] = mapped_column(primary_key=True)
    spiel_id: Mapped[int] = mapped_column(ForeignKey("spiel.id"))
    spieler_id: Mapped[int] = mapped_column(ForeignKey("spieler.id"))
    position: Mapped[int] = mapped_column(Integer)
    status: Mapped[ZusageStatus] = mapped_column(SAEnum(ZusageStatus), default=ZusageStatus.OFFEN)
    erstellt_am: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    spiel: Mapped["Spiel"] = relationship(back_populates="ersatzanfragen")
    spieler: Mapped["Spieler"] = relationship()
