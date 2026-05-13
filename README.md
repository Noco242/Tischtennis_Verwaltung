# TT-Match-Manager

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

## Abdeckung nach Anforderung

| Anforderung | Status | Befund | UI-Ergaenzung / Umsetzung |
|---|---:|---|---|
| Rollen: Administrator, Mannschaftsfuehrer, Spieler | Teilweise erfuellt | Backend hat Rollen, JWT-Auth und Rollenchecks. Admin-Rechte sind fuer Stammdaten vorhanden. Im Frontend gibt es aber keine vollstaendige rollenspezifische Verwaltungsoberflaeche. | Rollenbasiertes Hauptmenue mit Bereichen `Dashboard`, `Spiele`, `Team`, `Verwaltung`. Admin sieht Spieler/Mannschaften/Import, Mannschaftsfuehrer sieht eigene Team- und Spieltools, Spieler sieht nur eigene Spiele und Profil. |
| FA 1.1 Spielerdaten | Teilweise erfuellt | Backend-CRUD fuer Spieler mit Name, Kontakt, TTR, Status, Jugend-Flag. Frontend kann Spieler fuer Detailanzeigen laden, aber keine Admin-Maske zum Pflegen. | Admin-Screen `Spieler` mit Suchliste, Filter nach Status/Jugend/Team, Detailformular zum Anlegen/Bearbeiten und Self-Service-Profil fuer Telefonnummer/Passwort. |
| FA 1.2 Mannschaftshierarchie + Standardaufstellung | Teilweise erfuellt | Backend modelliert Mannschaftsrang, Fuehrer und Mitgliedschaft mit Standardposition. Frontend zeigt Aufstellungen, bietet aber keine vollstaendige UI zum Verwalten von Mannschaften oder Standardaufstellungen. | Admin-Screen `Mannschaften` mit Rangliste 1-n, Kapitaen-Auswahl und Teamdetail. Standardaufstellung per sortierbarer Liste oder Positionsfeldern 1-4 pflegen. |
| FA 1.3 Spielberechtigungen | Teilweise erfuellt | Status, Jugend-Flag, Stammspieler/Zweitspielrecht und Meldenummer sind modelliert. Zweitspielrecht ist getestet. Sperrvermerke und konkrete Jugend-Ersatz-Regeln sind nicht fachlich ausmodelliert. | In Spieler- und Teamdetail Berechtigungs-Badges anzeigen: Stammspieler, Zweitspielrecht, Jugend, gesperrt/passiv, Meldenummer. Beim Speichern Warnungen direkt unter dem Formular anzeigen. |
| FA 2.1 click-TT/myTischtennis Import | Teilweise erfuellt | Es gibt eine Import-Schnittstelle fuer bereits vorbereitete Spieldaten und einen click-TT-URL-Builder. Ein echter Crawler oder eine echte Schnittstellenanbindung fehlt. | Import-Screen fuer Admin: Verein/Saison/URL eingeben, Vorschau-Tabelle mit neuen/geaenderten Spielen, Konflikte markieren, danach `Import uebernehmen`. |
| FA 2.2 Aufstellungslogik | Teilweise erfuellt | Backend validiert lueckenlose/eindeutige Positionen, TTR-Reihenfolge, Absagen und Mannschaftsrang. Die Logik ist bewusst vereinfacht und deckt nicht die gesamte Wettspielordnung ab. | Mannschaftsfuehrer-Screen `Aufstellung bauen`: Spieler per Dropdown/Drag-and-drop auf Position 1-4 setzen, Button `Validieren`, Warn-/Fehlerbox anzeigen, danach `Freigeben`. |
| FA 2.3 Ersatz-Workflow | Teilweise erfuellt | Backend startet bei Absage eines aufgestellten Spielers einen Ersatzworkflow und legt Ersatzanfragen an. Der Nachrichtenausgang ist nur ein Stub. | In Spiel-Detail eine `Ersatz`-Sektion mit Timeline: angefragt, zugesagt, abgelehnt, naechster Kandidat. Spieler bekommen eine Ersatzanfrage-Karte mit `Annehmen` und `Ablehnen`. |
| FA 2.4 Spiel-PIN | Teilweise erfuellt | Backend-Endpoint fuer Zusage ohne Login ist vorhanden und getestet. Im Frontend ist keine sichtbare PIN-Eingabe erkennbar. | Oeffentliche PIN-Seite oder Deep-Link-Screen: Spiel-PIN eingeben bzw. Link oeffnen, Namen auswaehlen, mit zwei Buttons zu-/absagen. Kein Voll-Login erforderlich. |
| FA 3.1 "Wer kommt direkt?" / Fahrgemeinschaften | Offen bis teilweise | Ein allgemeines Notizfeld existiert und wird angezeigt. Eine eigene Fahrgemeinschafts-/Direktfahrer-Funktion oder UI zum Bearbeiten dieser Information ist nicht umgesetzt. | Eigene Sektion im Spiel-Detail: Toggle `Ich komme direkt`, Toggle `Ich fahre ab Treffpunkt`, optional `Plaetze im Auto` und Kommentar. Teamliste zeigt Direktfahrer und Treffpunktfahrer getrennt. |
| FA 3.2 Treffpunkt und Abfahrtszeit | Erfuellt im MVP | Backend-Endpoint und Frontend-Dialog fuer Treffpunkt/Zeit sind vorhanden. Backend prueft Admin/Mannschaftsfuehrer. | Bestehenden Dialog erweitern: getrennte Felder fuer Treffpunkt, Abfahrtszeit, Hinweistext und Kartenlink. Im Spielkopf dauerhaft sichtbar anzeigen. |
| FA 3.3 WhatsApp und E-Mail | Nicht produktiv erfuellt | Notification-Service kennt die Kanaele E-Mail und WhatsApp, schreibt aber nur ins Log. Kein realer Versand. | Einstellungs-Screen fuer Admin/Kapitaen: bevorzugte Kanaele pro Spieler, Nachrichtenvorlagen, Testversand und Versandstatus je Spiel/Ersatzanfrage. |
| NFA 4.1 Offline-First | Nicht erfuellt | Nur Login-Token/Rolle werden lokal persistiert. Kein Offline-Cache fuer Ort, Gegner, Aufstellung oder Sync-Konflikte. | Offline-Banner mit letztem Sync-Zeitpunkt, lokaler Cache fuer `meine Spiele`, Details und Aufstellung. Aktionen offline in Queue legen und nach Verbindung synchronisieren. |
| NFA 4.2 minimale Klickpfade | Teilweise erfuellt | Eingeloggte Nutzer koennen auf Dashboard und Detailseite direkt zu-/absagen. Der Spiel-PIN-Flow ist im Backend da, aber nicht im Frontend. | Dashboard-Quick-Actions beibehalten, Push/Mail/WhatsApp-Links direkt auf Quick-Reply/PIN-Screen fuehren. Statuswechsel ohne extra Dialog, nur kurze Snackbar als Bestaetigung. |
| NFA 4.3 DSGVO | Teilweise / Risiko | Endpoints sind grundsaetzlich authentifiziert, Telefonnummern werden intern ausgeliefert. Es fehlen Einwilligung, Rollen-/Team-Sichtbarkeit im Detail, Auskunft/Loeschung, Audit-Log und Datenschutztexte. Zudem enthaelt das ZIP eine `.env` und eine SQLite-DB. | Datenschutz-/Profilbereich mit Einwilligungen, Sichtbarkeit der Telefonnummer, Datenexport- und Loeschanfrage. UI blendet Kontaktdaten ausserhalb berechtigter Teams aus. |
| NFA 4.4 Kalender-Sync | Teilweise erfuellt | Dynamischer iCal-Feed ist vorhanden. Token ist im MVP aber nur die Spieler-ID und damit erratbar; keine native Kalender-Sync-Garantie innerhalb weniger Sekunden. | Kalender-Screen mit Abo-Link kopieren/teilen, `Token neu erzeugen`, Kalender-App oeffnen und Hinweis zum letzten Feed-Update. |
| Technische Architektur | Teilweise passend | Flutter + FastAPI passen zum Pflichtenheft. ZIP nutzt SQLite statt PostgreSQL und enthaelt keine produktive Cloud-/HTTPS-Konfiguration. | Kein Haupt-UI-Thema, aber sinnvoll: Admin-Systemstatus mit API-URL, Backend-Erreichbarkeit, App-Version und Sync-Status zur Fehlersuche. |
| UI/UX Dashboard | Groesstenteils erfuellt | Dashboard zeigt naechstes Spiel, eigenen Status, Team-Status, Ort und Navigation. Detailseite zeigt Aufstellung und Rueckmeldungen. | Dashboard um Namen im Team-Status erweitern: wer zugesagt, abgesagt, offen. Zusaetzlich naechste relevante Ersatzanfrage und Fahrgemeinschaftsstatus anzeigen. |
| Terminverschiebungen | Teilweise erfuellt | Backend benachrichtigt aufgestellte/zugesagte Spieler bei Terminverschiebung. Die geforderte Verfuegbarkeitsabfrage mit Optionen fehlt. | Screen `Terminverlegung`: Kapitaen erstellt Terminvorschlaege, Spieler stimmen verfuegbar/nicht verfuegbar ab, Kapitaen waehlt finalen Termin aus. |
| Heimspiel-Terminueberschneidungen | Teilweise erfuellt | Beim Anlegen wird eine Kollision als Notiz markiert. Eine manuelle Bestaetigung durch betroffene Mannschaftsfuehrer gibt es nicht. | Kollisionen als Warnmodal beim Spielanlegen anzeigen: betroffene Teams, Uhrzeiten, Halle. Button `Manuell bestaetigen` mit Kommentar und Status. |
| Kalenderuebersicht / iCal-Abo | Teilweise erfuellt | Spielliste und iCal-Abo-Link sind vorhanden. Eine echte Kalenderansicht ist nicht umgesetzt. | Kalenderansicht mit Monats-/Listenmodus, Filter nach Mannschaft/Spieler/Heimspiel, farbigen Statuspunkten und direktem iCal-Abo-CTA. |


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
