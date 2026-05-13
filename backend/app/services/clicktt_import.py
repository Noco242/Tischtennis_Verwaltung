"""Import-Schnittstelle fuer click-TT / mytischtennis.de.

MVP-Stub: Akzeptiert eine vorbereitete Liste von Spiel-Dicts. Spaeter
folgt ein echter Crawler oder eine offizielle Schnittstelle.

Erwartetes Datenformat::

    {
        "externe_id": "abc123",
        "gegner": "TTC Beispiel",
        "ist_heimspiel": true,
        "termin": "2026-05-20T19:30:00",
        "ort": "Sporthalle Musterstadt",
    }

Referenz-URL fuer den FC 1932 e.V. Kuelsheim::

    https://www.mytischtennis.de/click-tt/BaTTV/25--26/verein/1012/
    FC_1932_e.V._K%C3%BClsheim/spielplan
"""

from datetime import datetime
from typing import Iterable
from urllib.parse import quote

from sqlalchemy.orm import Session

from ..models import Mannschaft, Spiel


CLICKTT_BASIS = "https://www.mytischtennis.de/click-tt"


def spielplan_url(
    verband: str,
    saison: str,
    verein_id: int,
    vereinsname: str,
) -> str:
    """Baut den Spielplan-Link, wie ihn click-TT publiziert.

    Beispiel::

        spielplan_url("BaTTV", "25--26", 1012, "FC 1932 e.V. Kuelsheim")
    """
    safe_name = quote(vereinsname.replace(" ", "_"))
    return f"{CLICKTT_BASIS}/{verband}/{saison}/verein/{verein_id}/{safe_name}/spielplan"


def importiere_spiele(
    db: Session, mannschaft_id: int, spiele_daten: Iterable[dict]
) -> tuple[int, int]:
    """Importiert/aktualisiert Spiele fuer eine Mannschaft.

    Gibt (neu, aktualisiert) zurueck.
    """
    mannschaft = db.get(Mannschaft, mannschaft_id)
    if not mannschaft:
        raise ValueError("Mannschaft nicht gefunden")

    neu = 0
    aktualisiert = 0
    for daten in spiele_daten:
        externe_id = daten.get("externe_id")
        termin = daten["termin"]
        if isinstance(termin, str):
            termin = datetime.fromisoformat(termin)

        existing: Spiel | None = None
        if externe_id:
            existing = (
                db.query(Spiel)
                .filter(Spiel.mannschaft_id == mannschaft_id, Spiel.externe_id == externe_id)
                .first()
            )

        if existing:
            existing.gegner = daten.get("gegner", existing.gegner)
            existing.ist_heimspiel = daten.get("ist_heimspiel", existing.ist_heimspiel)
            existing.termin = termin
            existing.ort = daten.get("ort", existing.ort)
            aktualisiert += 1
        else:
            spiel = Spiel(
                mannschaft_id=mannschaft_id,
                gegner=daten.get("gegner", ""),
                ist_heimspiel=daten.get("ist_heimspiel", True),
                termin=termin,
                ort=daten.get("ort"),
                externe_id=externe_id,
            )
            db.add(spiel)
            neu += 1
    db.commit()
    return neu, aktualisiert
