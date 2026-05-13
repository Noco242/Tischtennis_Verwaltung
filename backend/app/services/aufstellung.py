"""Aufstellungs-Validierung und Ersatz-Logik gemaess Wettspielordnung.

Vereinfachte Heuristik fuer das MVP - die echte Meldeordnung des DTTB
kennt deutlich mehr Sonderregeln (Sperrvermerke, Spielklassen-Wechsel etc.).
"""

from typing import Iterable, Optional

from sqlalchemy.orm import Session

from ..models import (
    Aufstellung,
    Mannschaft,
    MannschaftsMitglied,
    Spieler,
    SpielerStatus,
    Spiel,
    Zusage,
    ZusageStatus,
)


# Bei Einsatz in einer hoeheren Mannschaft als der Stammmannschaft gilt
# ein Spieler grob als Ersatz, ab dieser Differenz warnen wir aktiv.
ERLAUBTE_AUFSTIEGS_DIFFERENZ = 2


def validiere_aufstellung(
    db: Session, spiel: Spiel, eintraege: list[tuple[int, int, bool]]
) -> tuple[list[str], list[str]]:
    """Prueft eine Aufstellung. Gibt (warnungen, fehler) zurueck.

    eintraege: list of (position, spieler_id, ist_ersatz).
    """
    warnungen: list[str] = []
    fehler: list[str] = []

    positionen = [p for p, _, _ in eintraege]
    if sorted(positionen) != list(range(1, len(positionen) + 1)):
        fehler.append("Positionen muessen luecklos 1..n sein.")

    if len(set(positionen)) != len(positionen):
        fehler.append("Positionen muessen eindeutig sein.")

    spieler_ids = [s for _, s, _ in eintraege]
    if len(set(spieler_ids)) != len(spieler_ids):
        fehler.append("Ein Spieler darf nur einmal aufgestellt werden.")

    mannschaft = db.get(Mannschaft, spiel.mannschaft_id)
    if not mannschaft:
        fehler.append("Mannschaft nicht gefunden.")
        return warnungen, fehler

    eigene_mitgliedschaften: dict[int, MannschaftsMitglied] = {
        m.spieler_id: m
        for m in db.query(MannschaftsMitglied)
        .filter(MannschaftsMitglied.mannschaft_id == mannschaft.id)
        .all()
    }

    spieler_obj: dict[int, Spieler] = {
        s.id: s for s in db.query(Spieler).filter(Spieler.id.in_(spieler_ids)).all()
    }

    # TTR-Rangordnung: hoeherer TTR -> kleinere Position.
    mit_ttr = [(pos, sid) for pos, sid, ersatz in eintraege if not ersatz]
    sortiert = sorted(
        mit_ttr,
        key=lambda x: (-(spieler_obj.get(x[1]).ttr or 0) if spieler_obj.get(x[1]) else 0),
    )
    if [p for p, _ in mit_ttr] != [p for p, _ in sortiert]:
        warnungen.append("Aufstellung weicht von der TTR-Rangordnung ab.")

    # Alle Mitgliedschaften aller aufgestellten Spieler vorab laden, damit wir
    # Mehrfach-Eintraege (Stammmeldung + Zweitspielrecht) korrekt beruecksichtigen.
    mitgliedschaften_je_spieler: dict[int, list[MannschaftsMitglied]] = {}
    if spieler_ids:
        for m in (
            db.query(MannschaftsMitglied)
            .filter(MannschaftsMitglied.spieler_id.in_(spieler_ids))
            .all()
        ):
            mitgliedschaften_je_spieler.setdefault(m.spieler_id, []).append(m)

    for pos, sid, ist_ersatz in eintraege:
        spieler = spieler_obj.get(sid)
        if not spieler:
            fehler.append(f"Spieler {sid} nicht gefunden (Position {pos}).")
            continue
        if spieler.status != SpielerStatus.AKTIV:
            fehler.append(f"{spieler.name} ist nicht aktiv (Position {pos}).")

        zusage = (
            db.query(Zusage)
            .filter(Zusage.spiel_id == spiel.id, Zusage.spieler_id == sid)
            .first()
        )
        if zusage and zusage.status == ZusageStatus.ABGESAGT:
            fehler.append(f"{spieler.name} hat abgesagt und kann nicht aufgestellt werden.")

        mitgliedschaften = mitgliedschaften_je_spieler.get(sid, [])

        # 1. Spieler ist in dieser Mannschaft eingetragen (Stamm oder Zweitspielrecht) -> ok.
        if sid in eigene_mitgliedschaften:
            continue

        # 2. Spieler ist in einer anderen Mannschaft Mitglied -> pruefe gegen
        #    die "hoechste" eigene Mannschaft (kleinster Rang = staerkste Klasse).
        if mitgliedschaften:
            beste = min(mitgliedschaften, key=lambda m: db.get(Mannschaft, m.mannschaft_id).rang)
            beste_mannschaft = db.get(Mannschaft, beste.mannschaft_id)
            diff = beste_mannschaft.rang - mannschaft.rang
            if diff > ERLAUBTE_AUFSTIEGS_DIFFERENZ:
                warnungen.append(
                    f"{spieler.name} ist hoechstens in der {beste_mannschaft.rang}. Mannschaft "
                    f"gemeldet und springt {diff} Klassen hoch - Meldeordnung pruefen."
                )
        else:
            warnungen.append(
                f"{spieler.name} ist in keiner Mannschaft gemeldet - Spielberechtigung pruefen."
            )

    return warnungen, fehler


def naechster_ersatzspieler(
    db: Session, spiel: Spiel, fuer_position: int
) -> Optional[Spieler]:
    """Findet den naechsten geeigneten Ersatzspieler nach TTR/Rang.

    Logik:
      1. Bereits in der Aufstellung stehende Spieler werden ausgeschlossen.
      2. Bereits angefragte oder abgesagte Spieler ebenfalls.
      3. Bevorzugt Stammspieler der eigenen Mannschaft, dann benachbarte
         Mannschaften (Rang +-2), danach nach TTR.
    """
    from ..models import Ersatzanfrage  # local import to avoid circulars

    bereits_aufgestellt = {a.spieler_id for a in spiel.aufstellung}
    abgesagt = {
        z.spieler_id
        for z in db.query(Zusage)
        .filter(Zusage.spiel_id == spiel.id, Zusage.status == ZusageStatus.ABGESAGT)
        .all()
    }
    bereits_angefragt = {
        e.spieler_id
        for e in db.query(Ersatzanfrage).filter(Ersatzanfrage.spiel_id == spiel.id).all()
    }
    ausgeschlossen = bereits_aufgestellt | abgesagt | bereits_angefragt

    mannschaft = db.get(Mannschaft, spiel.mannschaft_id)
    if not mannschaft:
        return None

    rows = (
        db.query(Spieler, Mannschaft)
        .join(MannschaftsMitglied, MannschaftsMitglied.spieler_id == Spieler.id)
        .join(Mannschaft, Mannschaft.id == MannschaftsMitglied.mannschaft_id)
        .filter(
            Spieler.status == SpielerStatus.AKTIV,
            ~Spieler.id.in_(ausgeschlossen) if ausgeschlossen else True,
            Mannschaft.rang >= mannschaft.rang,  # nicht aus einer staerkeren Klasse "absteigen"
            Mannschaft.rang <= mannschaft.rang + ERLAUBTE_AUFSTIEGS_DIFFERENZ,
        )
        .all()
    )

    # Pro Spieler: kleinster Rang-Abstand zu unserer Mannschaft (Spieler kann
    # in mehreren Mannschaften gemeldet sein, vgl. Zweitspielrecht).
    bester_pro_spieler: dict[int, tuple[Spieler, int]] = {}
    for spieler, m in rows:
        diff = abs(m.rang - mannschaft.rang)
        existing = bester_pro_spieler.get(spieler.id)
        if existing is None or diff < existing[1]:
            bester_pro_spieler[spieler.id] = (spieler, diff)

    if not bester_pro_spieler:
        return None

    sortiert = sorted(
        bester_pro_spieler.values(),
        key=lambda item: (item[1], -(item[0].ttr or 0)),
    )
    return sortiert[0][0]
