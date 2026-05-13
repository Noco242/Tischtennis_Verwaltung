from datetime import datetime, timedelta


def _auth(client, email, passwort):
    r = client.post("/auth/login", json={"email": email, "passwort": passwort})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _promote_to_admin(client, email):
    from app.models import Rolle, Spieler

    Session = client.app.state.test_session_maker
    db = Session()
    try:
        s = db.query(Spieler).filter(Spieler.email == email).first()
        assert s is not None
        s.rolle = Rolle.ADMIN
        db.commit()
    finally:
        db.close()


def test_register_login_health(client):
    r = client.get("/health")
    assert r.status_code == 200

    r = client.post(
        "/auth/register",
        json={"vorname": "Max", "nachname": "Muster", "email": "max@x.de", "passwort": "geheim123"},
    )
    assert r.status_code == 201, r.text
    token = r.json()["access_token"]
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "max@x.de"


def test_full_workflow(client):
    client.post(
        "/auth/register",
        json={"vorname": "A", "nachname": "Admin", "email": "a@x.de", "passwort": "geheim123"},
    )
    _promote_to_admin(client, "a@x.de")
    headers = _auth(client, "a@x.de", "geheim123")

    r = client.post("/mannschaften", json={"name": "1. Herren", "rang": 1}, headers=headers)
    assert r.status_code == 201, r.text
    mannschaft_id = r.json()["id"]

    sids = []
    for i in range(1, 5):
        r = client.post(
            "/spieler",
            json={
                "vorname": f"S{i}",
                "nachname": "T",
                "email": f"s{i}@x.de",
                "passwort": "test1234",
                "ttr": 1900 - i * 50,
            },
            headers=headers,
        )
        assert r.status_code == 201, r.text
        sids.append(r.json()["id"])

    for pos, sid in enumerate(sids, start=1):
        r = client.post(
            f"/mannschaften/{mannschaft_id}/mitglieder",
            json={"spieler_id": sid, "standardposition": pos, "ist_stammspieler": True},
            headers=headers,
        )
        assert r.status_code == 201, r.text

    termin = (datetime.utcnow() + timedelta(days=7)).isoformat()
    r = client.post(
        "/spiele",
        json={"mannschaft_id": mannschaft_id, "gegner": "Test e.V.", "termin": termin, "ist_heimspiel": True},
        headers=headers,
    )
    assert r.status_code == 201, r.text
    spiel_id = r.json()["id"]

    payload = {
        "eintraege": [{"position": p, "spieler_id": sids[p - 1], "ist_ersatz": False} for p in range(1, 5)],
        "freigeben": True,
    }
    r = client.post(f"/spiele/{spiel_id}/aufstellung/validieren", json=payload, headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["ok"] is True

    r = client.put(f"/spiele/{spiel_id}/aufstellung", json=payload, headers=headers)
    assert r.status_code == 200, r.text

    # Spieler-PIN-Zusage
    from app.models import Spiel

    Session = client.app.state.test_session_maker
    db = Session()
    try:
        pin = db.get(Spiel, spiel_id).pin
    finally:
        db.close()
    assert pin
    r = client.post(
        f"/spiele/{spiel_id}/zusage-pin",
        json={"pin": pin, "spieler_id": sids[0], "status": "zugesagt"},
    )
    assert r.status_code == 200, r.text

    # iCal-Feed
    r = client.get(f"/ical/{sids[0]}.ics")
    assert r.status_code == 200
    assert "BEGIN:VCALENDAR" in r.text


def test_absage_loest_ersatzanfrage_aus(client):
    client.post(
        "/auth/register",
        json={"vorname": "A", "nachname": "Admin", "email": "a@x.de", "passwort": "geheim123"},
    )
    _promote_to_admin(client, "a@x.de")
    headers = _auth(client, "a@x.de", "geheim123")

    r = client.post("/mannschaften", json={"name": "1. Herren", "rang": 1}, headers=headers)
    mid = r.json()["id"]

    sids = []
    for i in range(1, 6):
        r = client.post(
            "/spieler",
            json={
                "vorname": f"S{i}",
                "nachname": "T",
                "email": f"s{i}@x.de",
                "passwort": "test1234",
                "ttr": 1900 - i * 30,
            },
            headers=headers,
        )
        sids.append(r.json()["id"])
    for pos, sid in enumerate(sids, start=1):
        client.post(
            f"/mannschaften/{mid}/mitglieder",
            json={
                "spieler_id": sid,
                "standardposition": pos if pos <= 4 else None,
                "ist_stammspieler": True,
            },
            headers=headers,
        )

    termin = (datetime.utcnow() + timedelta(days=7)).isoformat()
    r = client.post(
        "/spiele",
        json={"mannschaft_id": mid, "gegner": "X", "termin": termin, "ist_heimspiel": True},
        headers=headers,
    )
    spiel_id = r.json()["id"]
    payload = {
        "eintraege": [{"position": p, "spieler_id": sids[p - 1], "ist_ersatz": False} for p in range(1, 5)],
        "freigeben": True,
    }
    client.put(f"/spiele/{spiel_id}/aufstellung", json=payload, headers=headers)

    headers_s1 = _auth(client, "s1@x.de", "test1234")
    client.post(f"/spiele/{spiel_id}/zusage", json={"status": "zugesagt"}, headers=headers_s1)
    client.post(f"/spiele/{spiel_id}/zusage", json={"status": "abgesagt"}, headers=headers_s1)

    r = client.get(f"/spiele/{spiel_id}/ersatzanfragen", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert len(body) >= 1
    # Erwartet: der erste nicht-aufgestellte Stammspieler (s5)
    assert body[0]["spieler_id"] == sids[4]
