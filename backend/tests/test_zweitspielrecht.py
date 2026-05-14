# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

"""Sicherstellen, dass die Anforderung 'Spieler flexibel in mehreren Mannschaften'
aus der Email-Vorgabe korrekt unterstuetzt wird.
"""

from datetime import datetime, timedelta


def _auth(client, email, passwort):
    r = client.post("/auth/login", json={"email": email, "passwort": passwort})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _promote_admin(client, email):
    from app.models import Rolle, Spieler

    db = client.app.state.test_session_maker()
    try:
        s = db.query(Spieler).filter(Spieler.email == email).first()
        s.rolle = Rolle.ADMIN
        db.commit()
    finally:
        db.close()


def _setup_zwei_mannschaften(client):
    """Legt 5. und 6. Mannschaft an und einen Spieler mit Zweitspielrecht
    (gemeldet 6.1, zusaetzlich Mitglied in 5er)."""
    client.post(
        "/auth/register",
        json={"vorname": "A", "nachname": "Admin", "email": "a@x.de", "passwort": "geheim123"},
    )
    _promote_admin(client, "a@x.de")
    h = _auth(client, "a@x.de", "geheim123")

    m5 = client.post("/mannschaften", json={"name": "5. Herren", "rang": 5}, headers=h).json()
    m6 = client.post("/mannschaften", json={"name": "6. Herren", "rang": 6}, headers=h).json()

    # 4 Stammspieler fuer m5
    m5_spieler = []
    for i in range(1, 5):
        r = client.post(
            "/spieler",
            json={
                "vorname": f"M5S{i}",
                "nachname": "X",
                "email": f"m5s{i}@x.de",
                "passwort": "demo1234",
                "ttr": 1200 - i * 10,
            },
            headers=h,
        )
        m5_spieler.append(r.json()["id"])
    for pos, sid in enumerate(m5_spieler, start=1):
        client.post(
            f"/mannschaften/{m5['id']}/mitglieder",
            json={"spieler_id": sid, "standardposition": pos, "ist_stammspieler": True,
                  "meldenummer": f"5.{pos}"},
            headers=h,
        )

    # Spieler mit Zweitspielrecht: gemeldet 6.1, ist auch in m5 Mitglied
    r = client.post(
        "/spieler",
        json={
            "vorname": "Zweit",
            "nachname": "Spieler",
            "email": "zweit@x.de",
            "passwort": "demo1234",
            "ttr": 1100,
        },
        headers=h,
    )
    zweit_id = r.json()["id"]
    client.post(
        f"/mannschaften/{m6['id']}/mitglieder",
        json={"spieler_id": zweit_id, "standardposition": 1, "ist_stammspieler": True,
              "meldenummer": "6.1"},
        headers=h,
    )
    client.post(
        f"/mannschaften/{m5['id']}/mitglieder",
        json={"spieler_id": zweit_id, "standardposition": None, "ist_stammspieler": False},
        headers=h,
    )

    return h, m5, m6, m5_spieler, zweit_id


def test_zweitspielrecht_loest_keine_warnung_aus(client):
    h, m5, _m6, m5_spieler, zweit_id = _setup_zwei_mannschaften(client)

    termin = (datetime.utcnow() + timedelta(days=7)).isoformat()
    r = client.post(
        "/spiele",
        json={"mannschaft_id": m5["id"], "gegner": "Auswaerts", "termin": termin, "ist_heimspiel": True},
        headers=h,
    )
    spiel_id = r.json()["id"]

    # Aufstellung: Position 1 fuer den Zweit-Spielrecht-Spieler (gemeldet 6.1,
    # aber in m5 als Zweitspielrecht eingetragen). Plus drei Stammspieler.
    payload = {
        "eintraege": [
            {"position": 1, "spieler_id": zweit_id, "ist_ersatz": False},
            {"position": 2, "spieler_id": m5_spieler[0], "ist_ersatz": False},
            {"position": 3, "spieler_id": m5_spieler[1], "ist_ersatz": False},
            {"position": 4, "spieler_id": m5_spieler[2], "ist_ersatz": False},
        ],
        "freigeben": False,
    }
    r = client.post(f"/spiele/{spiel_id}/aufstellung/validieren", json=payload, headers=h)
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert body["fehler"] == []
    # Keine "springt X Klassen hoch"-Warnung, weil er explizit in m5 eingetragen ist
    assert not any("springt" in w for w in body["warnungen"]), body["warnungen"]


def test_ohne_mitgliedschaft_loest_warnung_aus(client):
    """Negativfall: Spieler ist nur in 6. Mannschaft eingetragen, soll aber in m2
    aufgestellt werden -> Warnung 'springt X Klassen hoch'."""
    h, _m5, m6, _, _ = _setup_zwei_mannschaften(client)

    # zusaetzliche m2 erstellen
    m2 = client.post("/mannschaften", json={"name": "2. Herren", "rang": 2}, headers=h).json()

    # Spieler nur in m6 eingetragen
    r = client.post(
        "/spieler",
        json={
            "vorname": "Nur6",
            "nachname": "Y",
            "email": "nur6@x.de",
            "passwort": "demo1234",
            "ttr": 1000,
        },
        headers=h,
    )
    sid = r.json()["id"]
    client.post(
        f"/mannschaften/{m6['id']}/mitglieder",
        json={"spieler_id": sid, "standardposition": 4, "ist_stammspieler": True, "meldenummer": "6.4"},
        headers=h,
    )

    # Vier Stammspieler fuer m2 (sonst Validierungs-Fehler "luecklos")
    m2_spieler = []
    for i in range(1, 5):
        r = client.post(
            "/spieler",
            json={
                "vorname": f"M2S{i}",
                "nachname": "Y",
                "email": f"m2s{i}@x.de",
                "passwort": "demo1234",
                "ttr": 1700 - i * 20,
            },
            headers=h,
        )
        m2_spieler.append(r.json()["id"])
    for pos, s in enumerate(m2_spieler, start=1):
        client.post(
            f"/mannschaften/{m2['id']}/mitglieder",
            json={"spieler_id": s, "standardposition": pos, "ist_stammspieler": True,
                  "meldenummer": f"2.{pos}"},
            headers=h,
        )

    termin = (datetime.utcnow() + timedelta(days=10)).isoformat()
    r = client.post(
        "/spiele",
        json={"mannschaft_id": m2["id"], "gegner": "X", "termin": termin, "ist_heimspiel": True},
        headers=h,
    )
    spiel_id = r.json()["id"]
    payload = {
        "eintraege": [
            {"position": 1, "spieler_id": sid, "ist_ersatz": False},
            {"position": 2, "spieler_id": m2_spieler[0], "ist_ersatz": False},
            {"position": 3, "spieler_id": m2_spieler[1], "ist_ersatz": False},
            {"position": 4, "spieler_id": m2_spieler[2], "ist_ersatz": False},
        ],
        "freigeben": False,
    }
    r = client.post(f"/spiele/{spiel_id}/aufstellung/validieren", json=payload, headers=h)
    assert r.status_code == 200
    body = r.json()
    # Erwartet eine Warnung, weil der Spieler 4 Klassen hochspringt (6 -> 2)
    assert any("springt" in w for w in body["warnungen"]), body


def test_clicktt_spielplan_url_default_fc_kuelsheim(client):
    client.post(
        "/auth/register",
        json={"vorname": "X", "nachname": "Y", "email": "u@x.de", "passwort": "geheim123"},
    )
    h = _auth(client, "u@x.de", "geheim123")
    r = client.get("/clicktt/spielplan-url", headers=h)
    assert r.status_code == 200, r.text
    url = r.json()["url"]
    assert url.startswith("https://www.mytischtennis.de/click-tt/BaTTV/25--26/verein/1012/")
    assert "spielplan" in url
