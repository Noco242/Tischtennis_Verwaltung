# TT-Match-Manager

Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

Cross-Platform-App zur Tischtennis-Vereinsverwaltung gemaess Pflichtenheft V2
(`Vorgaben/Pflichtenheft_TT_Match_Manager.docx`).

Diese erste Iteration enthaelt ein lauffaehiges **MVP-Grundgeruest**:

- Python/FastAPI-Backend mit JWT-Auth, Rollen, Stammdaten, Spielen,
  Aufstellungs-Validierung, automatischer Ersatzspieler-Logik, Spiel-PIN,
  iCal-Feed sowie Stubs fuer click-TT-Import und WhatsApp/E-Mail-Versand.
- Flutter-Frontend (Android/iOS/Web) mit Login, Dashboard, Spielliste,
  Spiel-Detail und 2-Klick-Zusage.
- Seed-Daten und automatisierter Smoke-Test (`pytest`).

> **Hinweis:** Externe Integrationen (Crawler fuer mytischtennis.de,
> echter WhatsApp-/E-Mail-Versand, echte click-TT-Schnittstelle) sind
> bewusst als Stub angelegt. Sie sind ueber `app/services/*` zentral
> austauschbar.

## Verzeichnisstruktur

```
app/
  backend/          FastAPI-Backend
    app/
      main.py
      config.py
      database.py
      security.py
      deps.py
      seed.py
      models/        SQLAlchemy-Modelle
      schemas/       Pydantic-Schemas
      routers/       HTTP-Endpunkte
      services/      Aufstellungs-Logik, Notifications, iCal, click-TT
    tests/           Pytest-Smoke-Tests
    requirements.txt
    .env.example
  frontend/         Flutter-Projekt
    lib/
      main.dart
      models/
      services/      ApiClient, AuthState
      screens/       Login, Dashboard, Spielliste, Spiel-Detail
    pubspec.yaml
```

## Backend (Python 3.11+, getestet mit 3.14)

### 1. Installieren

```powershell
cd app/backend
py -m venv .venv
. .venv/Scripts/Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

### 2. Demo-Daten erzeugen

```powershell
python -m app.seed
```

Der Seed erzeugt einen Demo-Verein **FC 1932 e.V. Kuelsheim** (gemaess
Email-Vorgabe vom Auftraggeber, alle Kontaktdaten fiktiv) mit:

- 6 Herren-Mannschaften (1.-6. Mannschaft, Bezirksoberliga bis 2. Kreisliga)
- 28 Spielern inkl. Admin und 6 Kapitaenen
- 19 Spielen ueber die Saison verteilt
- Exemplarischen **Zweitspielrechten** (z.B. ein in der 6. Mannschaft
  gemeldeter Spieler ist zusaetzlich in der 5. einsetzbar)

Testaccounts:

| Rolle              | E-Mail                              | Passwort   |
|--------------------|-------------------------------------|------------|
| Admin              | anna.admin@example.com              | admin123   |
| Kapitaen 1. Herren | markus.schmitt@example.com          | kapitaen   |
| Kapitaen 2. Herren | rainer.fischer@example.com          | kapitaen   |
| Kapitaen 3. Herren | michael.weber@example.com           | kapitaen   |
| Kapitaen 4. Herren | joachim.schaefer@example.com        | kapitaen   |
| Kapitaen 5. Herren | dirk.schulz@example.com             | kapitaen   |
| Kapitaen 6. Herren | sven.richter@example.com            | kapitaen   |
| Alle Spieler       | `vorname.nachname@example.com`      | demo1234   |

### 3. Server starten

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger-UI: http://localhost:8000/docs

### Deployment-Check-in

Das Backend enthaelt einen transparenten Deployment-Check-in. Er ist
standardmaessig aktiv, sendet aber nur dann Pings, wenn eine Ziel-URL gesetzt
ist. Das Backend meldet sich beim Start und danach alle 2 Stunden. Das
Frontend meldet sich beim Laden der App und danach alle 2 Stunden ueber das
Backend, damit der Discord-Webhook nicht im Browser-Code offengelegt wird:

```powershell
DEPLOYMENT_ID=verein-prod
DEPLOYMENT_CHECKIN_ENABLED=true
DEPLOYMENT_CHECKIN_URL=https://example.org/ttmm-checkin
DEPLOYMENT_CHECKIN_INTERVAL_SECONDS=7200
```

Discord-Webhooks werden automatisch erkannt und als Discord-Nachricht mit Embed
gesendet. Andere HTTPS-Ziele erhalten das rohe JSON. Gesendet werden nur
App-Name, Version, Deployment-ID, Zeitstempel, Laufzeit, IP-Informationen und
Copyright-/Nutzungshinweis.
Ohne `DEPLOYMENT_CHECKIN_URL` oder mit `DEPLOYMENT_CHECKIN_ENABLED=false`
findet keine externe Uebertragung statt.

Das Frontend kann bei Bedarf per Dart-Define deaktiviert oder anders getaktet
werden:

```powershell
flutter run --dart-define=FRONTEND_CHECKIN_ENABLED=false
flutter run --dart-define=FRONTEND_CHECKIN_INTERVAL_SECONDS=7200
```

### 4. Tests

```powershell
pytest -v
```

## Frontend (Flutter)

Voraussetzung: Flutter SDK 3.19+ (https://flutter.dev/docs/get-started/install).

### 1. Plattformordner erzeugen (einmalig)

Das Repository enthaelt nur den `lib/`-Code und `pubspec.yaml`. Die
plattformspezifischen Ordner (`android/`, `ios/`, `web/`, ...) werden
mit folgendem Befehl generiert:

```powershell
cd app/frontend
flutter create . --org de.verein --project-name tt_match_manager
flutter pub get
```

### 2. Backend-URL setzen

Per Default verbindet sich die App mit `http://localhost:8000`. Fuer
Android-Emulatoren ist die Host-IP `10.0.2.2`:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Abdeckung des Pflichtenhefts

| Anforderung | Status | Hinweis |
|-------------|--------|---------|
| Rollen Admin / Mannschaftsfuehrer / Spieler | umgesetzt | JWT + Rollencheck (`app/deps.py`) |
| FA 1.1 Spielerdaten | umgesetzt | `/spieler` CRUD |
| FA 1.2 Mannschaftshierarchie + Standardaufstellung | umgesetzt | `Mannschaft.rang`, `MannschaftsMitglied.standardposition` |
| FA 1.3 Spielberechtigungen + Zweitspielrecht | umgesetzt | `MannschaftsMitglied` erlaubt einen Spieler in beliebig vielen Mannschaften (`meldenummer`, `ist_stammspieler`); siehe Email-Hinweis "auf 6.1 gemeldet, spielt aber auch in der 5." |
| FA 2.1 click-TT-Import | Stub | `services/clicktt_import.py` mit `spielplan_url(...)` (Default FC Kuelsheim) und `GET /clicktt/spielplan-url`; echter Crawler folgt |
| FA 2.2 Aufstellungs-Validierung | umgesetzt | `services/aufstellung.validiere_aufstellung` warnt bei TTR-Verstoss + Klassen-Sprung; respektiert Zweitspielrecht |
| FA 2.3 Ersatz-Workflow | umgesetzt | Automatisch ausgeloest bei Absage eines Aufgestellten |
| FA 2.4 Spiel-PIN | umgesetzt | `POST /spiele/{id}/zusage-pin` |
| FA 3.1 "Wer kommt direkt?" | umgesetzt | `Spiel.notiz`, im UI editierbar |
| FA 3.2 Treffpunkt | umgesetzt | `POST /spiele/{id}/treffpunkt` |
| FA 3.3 WhatsApp/E-Mail | Stub | `services/notifications.py`, Logging-Ausgabe |
| NFA 4.1 Offline-First | minimal | Tokens lokal persistiert; vollstaendiger Offline-Cache offen |
| NFA 4.2 Usability (2-Klick-Zusage) | umgesetzt | Dashboard-Karte |
| NFA 4.3 DSGVO | strukturell | Telefonnummern nur fuer angemeldete Nutzer, keine Public-Endpoints; DSGVO-Texte offen |
| NFA 4.4 Performance / iCal | umgesetzt | dynamischer Abo-Link `/ical/{token}.ics` |
| Terminkollision Heimspiele | umgesetzt | beim Anlegen geprueft, Hinweis in `Spiel.notiz` |

## Hinweis aus der Email-Vorgabe (Zweitspielrecht)

> "Wichtig waere, dass es trotzdem flexibel ist, weil wie du weisst, ich
> auf 6.1 gemeldet bin, aber auch in der 5. Mannschaft mitspiele. Wenn
> man Einteilungen macht, waere es super, wenn alle Spieler auch fuer
> andere Mannschaften eingesetzt werden koennen, unabhaengig ihrer
> Meldung."

Diese Anforderung wird vollstaendig unterstuetzt:

- Ein Spieler kann beliebig viele Eintraege in `mannschafts_mitglied`
  haben. Genau ein Eintrag mit `ist_stammspieler=True` (Stammmeldung
  mit `meldenummer` wie `"6.1"`), beliebige weitere mit Zweitspielrecht.
- Die Aufstellungs-Validierung warnt **nicht**, wenn der Spieler bereits
  Mitglied der aufstellenden Mannschaft ist - auch wenn das nur
  Zweitspielrecht ist.
- Die Validierung warnt nur dann ("springt X Klassen hoch"), wenn der
  Spieler aus einer deutlich tieferen Mannschaft ohne jegliche
  Mitgliedschaft hochgezogen wird (Schwelle: `ERLAUBTE_AUFSTIEGS_DIFFERENZ`
  in `services/aufstellung.py`).
- Pytest deckt beide Faelle ab (`tests/test_zweitspielrecht.py`).

## Naechste Iterationen

1. Echter click-TT-Crawler (HTML-Parsing der Spielplan-URL, siehe
   `services/clicktt_import.py`). Vorlage fuer FC Kuelsheim:
   `https://www.mytischtennis.de/click-tt/BaTTV/25--26/verein/1012/FC_1932_e.V._K%C3%BClsheim/spielplan`
   (Saison-Filter September-Mai liefert alle gespielten Begegnungen).
2. WhatsApp Business und SMTP-Anbindung (z.B. Twilio / SendGrid).
3. Offline-Sync mit lokalem SQLite-Cache in der App (Hive/Drift).
4. Push-Benachrichtigungen (Firebase Cloud Messaging).
5. Admin-/Mannschaftsfuehrer-Screens (Spieler anlegen, Aufstellung bauen).
6. Saisonverwaltung mit Spielklassen, Sperrvermerken und Jugend-Ersatz-Regel.
7. DSGVO-Begleittexte, Einwilligungsmanagement, Audit-Log.
