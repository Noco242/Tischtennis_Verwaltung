# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

"""Seed-Daten fuer Entwicklung und Demo.

Demo-Verein: FC 1932 e.V. Kuelsheim (Saison 2025/26).
Spielerstruktur ist plausibel, Kontaktdaten (Mail/Telefon) sind FIKTIV
zu Demo-Zwecken (siehe E-Mail-Vorgabe vom Auftraggeber).

Aufruf::

    python -m app.seed
"""

from datetime import datetime, timedelta

from .database import Base, SessionLocal, engine
from .models import (
    Mannschaft,
    MannschaftsMitglied,
    Rolle,
    Spieler,
    SpielerStatus,
    Spiel,
)
from .security import hash_password


VEREIN = "FC 1932 e.V. Külsheim"


_used_emails: set[str] = set()


def _spieler(vorname: str, nachname: str, ttr: int, *, rolle: Rolle = Rolle.SPIELER,
             passwort: str = "demo1234", telefon_suffix: str = "0000",
             jugend: bool = False) -> Spieler:
    base = f"{vorname.lower()}.{nachname.lower()}".replace(" ", "")
    email = f"{base}@example.com"
    i = 2
    while email in _used_emails:
        email = f"{base}{i}@example.com"
        i += 1
    _used_emails.add(email)
    return Spieler(
        vorname=vorname,
        nachname=nachname,
        email=email,
        telefon=f"0151-555-{telefon_suffix}",
        ttr=ttr,
        rolle=rolle,
        passwort_hash=hash_password(passwort),
        jugend=jugend,
    )


def run() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # --- Personen ----------------------------------------------------
        admin = _spieler("Anna", "Admin", 1500, rolle=Rolle.ADMIN, passwort="admin123", telefon_suffix="0001")

        # Mannschaftsfuehrer fuer 1. bis 6. Herren - fiktive Namen
        kapitaen_namen = [
            ("Markus", "Schmitt", 1820),
            ("Rainer", "Fischer", 1640),
            ("Michael", "Weber", 1500),
            ("Joachim", "Schaefer", 1360),
            ("Dirk", "Schulz", 1220),
            ("Sven", "Richter", 1100),
        ]
        fuehrer = [
            _spieler(v, n, ttr, rolle=Rolle.MANNSCHAFTSFUEHRER, passwort="kapitaen",
                     telefon_suffix=f"010{i}")
            for i, (v, n, ttr) in enumerate(kapitaen_namen, start=1)
        ]

        # Stammspieler je Mannschaft (4 pro Team) - Namen fiktiv
        spieler_pro_team = {
            1: [("Thomas", "Wagner", 1790), ("Stefan", "Hofmann", 1760), ("Daniel", "Becker", 1740)],
            2: [("Klaus", "Berger", 1620), ("Peter", "Lehmann", 1610), ("Andreas", "Roth", 1590)],
            3: [("Florian", "Mayer", 1480), ("Tobias", "Vogel", 1460), ("Sebastian", "Kraus", 1440)],
            4: [("Jens", "Frank", 1340), ("Holger", "Sauer", 1320), ("Uwe", "Lange", 1300)],
            5: [("Martin", "Krug", 1210), ("Bernd", "Knorr", 1180), ("Joerg", "Pfeiffer", 1160)],
            6: [("Lukas", "Klein", 1080), ("Tim", "Hartmann", 1050), ("Robin", "Walter", 1020)],
        }
        ergaenzungs = {
            1: [],
            2: [("Christoph", "Engel", 1650)],
            3: [],
            4: [("Alex", "Renner", 1290)],
            5: [],
            6: [("Jonas", "Bauer", 1010, True)],  # Jugendspieler
        }

        alle_personen: list[Spieler] = [admin, *fuehrer]
        team_spieler: dict[int, list[Spieler]] = {i: [] for i in range(1, 7)}

        suffix_counter = 200
        for rang, liste in spieler_pro_team.items():
            for vorname, nachname, ttr in liste:
                s = _spieler(vorname, nachname, ttr, telefon_suffix=f"{suffix_counter:04d}")
                alle_personen.append(s)
                team_spieler[rang].append(s)
                suffix_counter += 1

        ergaenzungs_spieler: dict[int, list[Spieler]] = {i: [] for i in range(1, 7)}
        for rang, liste in ergaenzungs.items():
            for entry in liste:
                if len(entry) == 4:
                    vorname, nachname, ttr, jugend = entry
                else:
                    vorname, nachname, ttr = entry
                    jugend = False
                s = _spieler(vorname, nachname, ttr, telefon_suffix=f"{suffix_counter:04d}", jugend=jugend)
                alle_personen.append(s)
                ergaenzungs_spieler[rang].append(s)
                suffix_counter += 1

        db.add_all(alle_personen)
        db.commit()

        # --- Mannschaften ------------------------------------------------
        mannschaften: dict[int, Mannschaft] = {}
        spielklassen = {
            1: "Bezirksoberliga",
            2: "Bezirksliga",
            3: "Bezirksklasse A",
            4: "Bezirksklasse B",
            5: "1. Kreisliga",
            6: "2. Kreisliga",
        }
        for rang in range(1, 7):
            m = Mannschaft(
                name=f"{rang}. Herren",
                rang=rang,
                spielklasse=spielklassen[rang],
                fuehrer_id=fuehrer[rang - 1].id,
            )
            db.add(m)
            mannschaften[rang] = m
        db.commit()

        # --- Mitgliedschaften -------------------------------------------
        # Mannschaftsfuehrer ist Stammspieler auf Position 1 seiner Mannschaft
        for rang, m in mannschaften.items():
            db.add(
                MannschaftsMitglied(
                    spieler_id=fuehrer[rang - 1].id,
                    mannschaft_id=m.id,
                    standardposition=1,
                    ist_stammspieler=True,
                    meldenummer=f"{rang}.1",
                )
            )
            for pos, sp in enumerate(team_spieler[rang], start=2):
                db.add(
                    MannschaftsMitglied(
                        spieler_id=sp.id,
                        mannschaft_id=m.id,
                        standardposition=pos,
                        ist_stammspieler=True,
                        meldenummer=f"{rang}.{pos}",
                    )
                )
            for sp in ergaenzungs_spieler[rang]:
                db.add(
                    MannschaftsMitglied(
                        spieler_id=sp.id,
                        mannschaft_id=m.id,
                        standardposition=None,
                        ist_stammspieler=True,
                    )
                )

        # Zweitspielrecht (Hinweis vom Kollegen: "ich auf 6.1 gemeldet,
        # spiele aber auch in der 5. Mannschaft"). Wir bilden das exemplarisch
        # fuer mehrere Spieler ab, damit der Anwendungsfall sichtbar ist.
        zweitspielrechte = [
            # (Spieler, Mannschaft-Rang in der er zusaetzlich eingesetzt wird)
            (team_spieler[6][0], 5),  # auf 6.x gemeldet, hilft in der 5. aus
            (team_spieler[5][0], 4),  # Martin Krug: gemeldet 5.1, spielt auch in 4.
            (team_spieler[4][0], 3),
            (team_spieler[3][0], 2),
        ]
        for sp, ziel_rang in zweitspielrechte:
            db.add(
                MannschaftsMitglied(
                    spieler_id=sp.id,
                    mannschaft_id=mannschaften[ziel_rang].id,
                    standardposition=None,
                    ist_stammspieler=False,
                )
            )
        db.commit()

        # --- Spielplan (Saison September - Mai) -------------------------
        saison_start = datetime(datetime.utcnow().year, 9, 15, 19, 30)
        spieltage = [saison_start + timedelta(days=14 * i) for i in range(15)]
        gegner_pro_team = {
            1: ["TTC Marktheidenfeld", "TSV Roettingen", "DJK Hammelburg", "TTC Lohr"],
            2: ["TV Wertheim", "DJK Werbach", "TSV Tauberbischofsheim 2"],
            3: ["TSV Assamstadt", "TG Lauda", "FC Hundheim"],
            4: ["TV Reicholzheim", "TSV Bestenheid", "SV Distelhausen"],
            5: ["TSV Werbach 2", "DJK Eiersheim", "TSV Wenkheim"],
            6: ["TTC Hardheim 2", "FC Gerchsheim", "TSV Boxberg"],
        }
        spiele: list[Spiel] = []
        for rang, gegner_liste in gegner_pro_team.items():
            for i, gegner in enumerate(gegner_liste):
                termin = spieltage[i % len(spieltage)] + timedelta(days=rang)
                ist_heim = (i + rang) % 2 == 0
                spiele.append(
                    Spiel(
                        mannschaft_id=mannschaften[rang].id,
                        gegner=gegner,
                        ist_heimspiel=ist_heim,
                        termin=termin,
                        ort=(
                            "TT-Akademie Kuelsheim, Wuerzburger Str. 4"
                            if ist_heim
                            else f"Sporthalle {gegner}"
                        ),
                        externe_id=f"clicktt-2526-{rang}-{i}",
                    )
                )
        # PIN je Spiel
        import secrets

        for s in spiele:
            s.pin = secrets.token_urlsafe(6)[:8]
        db.add_all(spiele)
        db.commit()

        print(f"Seed abgeschlossen ({VEREIN}, Saison {saison_start.year}/{saison_start.year + 1}).")
        print(f"  Mannschaften:  {len(mannschaften)}")
        print(f"  Spieler:       {len(alle_personen)} (inkl. Admin und {len(fuehrer)} Kapitaene)")
        print(f"  Spiele:        {len(spiele)}")
        print()
        print("Test-Accounts:")
        print(f"  Admin:          {admin.email}  / admin123")
        for i, k in enumerate(fuehrer, start=1):
            print(f"  Kapitaen M{i}:    {k.email}  / kapitaen")
        print("  Alle Spieler:   vorname.nachname@example.com  / demo1234")
    finally:
        db.close()


if __name__ == "__main__":
    run()
