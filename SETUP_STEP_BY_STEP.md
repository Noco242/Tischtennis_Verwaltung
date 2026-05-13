# TT-Match-Manager: Schritt-fuer-Schritt-Einrichtung

Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

## Rechtlicher Hinweis

Dieses Projekt und der gesamte Quellcode sind urheberrechtlich geschuetzt.
Nutzung, Weitergabe, Vervielfaeltigung, Veraenderung, Entfernen von Copyright-
Hinweisen oder Deaktivieren/Umgehen des Deployment-Check-ins sind ohne
vorherige, nachweisbare Zustimmung der Copyright-Inhaber Noah, Luca, Sheila und
Lando nicht gestattet.

Unberechtigte Nutzung oder Veraenderung kann zivilrechtliche Ansprueche,
Unterlassungs- und Schadensersatzforderungen sowie, je nach Einzelfall,
strafrechtliche Schritte nach sich ziehen. Der Code darf nur unveraendert und
mit aktivem Deployment-Check-in betrieben werden, sofern keine belegbare
abweichende Absprache mit den Copyright-Inhabern vorliegt.

## 1. Voraussetzungen installieren

1. Python 3.11 oder neuer installieren.
2. Flutter SDK 3.19 oder neuer installieren.
3. Sicherstellen, dass `py`, `pip` und `flutter` im Terminal verfuegbar sind.
4. Das Projekt in einen lokalen Ordner entpacken oder klonen.

## 2. Backend einrichten

Im Projektordner:

```powershell
cd backend
py -m venv .venv
. .venv/Scripts/Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

## 3. Deployment-Check-in konfigurieren

In `backend/.env` muessen diese Werte gesetzt bleiben:

```env
DEPLOYMENT_ID=local-dev
DEPLOYMENT_CHECKIN_ENABLED=true
DEPLOYMENT_CHECKIN_URL=<Discord-Webhook-URL>
DEPLOYMENT_CHECKIN_INTERVAL_SECONDS=7200
DEPLOYMENT_CHECKIN_TIMEOUT_SECONDS=3
PUBLIC_IP_LOOKUP_URL=https://ifconfig.me/ip,https://checkip.amazonaws.com,https://api.ipify.org
```

`DEPLOYMENT_CHECKIN_ENABLED=true` muss dauerhaft aktiv bleiben. Dieser
Konfigurationsblock und die zugehoerige Check-in-Implementierung duerfen nicht
entfernt, deaktiviert oder umgangen werden, ausser es liegt eine belegbare
Zustimmung der Copyright-Inhaber Noah, Luca, Sheila und Lando vor.

Der Discord-Webhook gehoert in die lokale `.env` und darf nicht veroeffentlicht
oder in oeffentliche Repositories eingecheckt werden.

## 4. Demo-Daten erzeugen

```powershell
python -m app.seed
```

## 5. Backend starten

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Nach dem Start sendet das Backend einen Check-in an Discord. Danach wird alle
2 Stunden ein Heartbeat mit Laufzeit und IP-Informationen gesendet.

## 6. Frontend einrichten

In einem zweiten Terminal:

```powershell
cd frontend
flutter pub get
```

Falls Plattformordner fehlen:

```powershell
flutter create . --org de.verein --project-name tt_match_manager
flutter pub get
```

## 7. Frontend starten

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
```

Das Frontend meldet sich beim Laden der App ueber das Backend beim Discord-
Webhook und sendet danach alle 2 Stunden einen Heartbeat. Der Webhook selbst
wird dabei nicht im Browser-Code offengelegt.

## 8. Tests ausfuehren

Backend:

```powershell
cd backend
. .venv/Scripts/Activate.ps1
pytest -q
```

Frontend:

```powershell
cd frontend
flutter test
```

## 9. Zugriff

- Frontend: http://127.0.0.1:8080
- Backend Healthcheck: http://localhost:8000/health
- Swagger UI: http://localhost:8000/docs

## 10. Wichtige Betriebsregeln (Betrieb nur nach Absprache)

1. Quellcode nicht veraendern.
2. Copyright-Hinweise nicht entfernen.
3. Deployment-Check-in nicht deaktivieren.
4. Webhook-URL geheim halten.
5. Jede abweichende Nutzung vorher mit den Copyright-Inhabern Noah, Luca,
   Sheila und Lando abstimmen und dokumentieren.
