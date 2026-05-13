"""iCal-Feed pro Spieler.

Verwendet die `ics`-Bibliothek. Liefert einen dynamischen Abo-Link, der
bei Verlegungen automatisch aktualisiert wird (NFA 4.4).
"""

from datetime import timedelta

from ics import Calendar, Event
from sqlalchemy.orm import Session

from ..models import Aufstellung, MannschaftsMitglied, Spiel, Spieler


def ical_fuer_spieler(db: Session, spieler: Spieler) -> str:
    cal = Calendar()
    cal.creator = "TT-Match-Manager//DE"

    mannschaft_ids = [
        m.mannschaft_id
        for m in db.query(MannschaftsMitglied).filter(MannschaftsMitglied.spieler_id == spieler.id).all()
    ]
    aufstellungen_spiel_ids = {
        a.spiel_id
        for a in db.query(Aufstellung).filter(Aufstellung.spieler_id == spieler.id).all()
    }

    spiele = (
        db.query(Spiel)
        .filter(
            (Spiel.mannschaft_id.in_(mannschaft_ids))
            | (Spiel.id.in_(aufstellungen_spiel_ids) if aufstellungen_spiel_ids else False)
        )
        .all()
    )

    for spiel in spiele:
        event = Event()
        event.uid = f"spiel-{spiel.id}@tt-match-manager"
        ist_heim = spiel.ist_heimspiel
        event.name = (
            f"TT: {spiel.mannschaft.name} vs {spiel.gegner}"
            if ist_heim
            else f"TT: {spiel.gegner} vs {spiel.mannschaft.name}"
        )
        event.begin = spiel.termin
        event.duration = timedelta(hours=3)
        if spiel.ort:
            event.location = spiel.ort
        notiz_teile = []
        if spiel.treffpunkt_ort and spiel.treffpunkt_zeit:
            notiz_teile.append(
                f"Treffpunkt: {spiel.treffpunkt_ort} um {spiel.treffpunkt_zeit:%H:%M}"
            )
        if spiel.notiz:
            notiz_teile.append(spiel.notiz)
        if notiz_teile:
            event.description = "\n".join(notiz_teile)
        cal.events.add(event)

    return cal.serialize()
