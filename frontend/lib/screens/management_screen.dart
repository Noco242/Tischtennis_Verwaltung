// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/mannschaft.dart';
import '../models/spieler.dart';
import '../services/api_client.dart';
import '../services/auth_state.dart';
import '../theme.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late Future<_ManagementData> _future;
  final _spielerVorname = TextEditingController();
  final _spielerNachname = TextEditingController();
  final _spielerEmail = TextEditingController();
  final _spielerTelefon = TextEditingController();
  final _spielerTtr = TextEditingController();
  final _spielerPasswort = TextEditingController(text: 'demo1234');
  Rolle _spielerRolle = Rolle.spieler;
  bool _spielerJugend = false;

  final _teamName = TextEditingController();
  final _teamRang = TextEditingController();
  final _teamKlasse = TextEditingController();
  int? _teamFuehrerId;

  final _mitgliedPosition = TextEditingController();
  final _mitgliedMeldenummer = TextEditingController();
  int? _mitgliedTeamId;
  int? _mitgliedSpielerId;
  bool _mitgliedStamm = true;

  final _importText = TextEditingController(
    text:
        '[{"externe_id":"demo-1","gegner":"TTC Beispiel","ist_heimspiel":true,"termin":"2026-10-03T18:00:00","ort":"Beispielhalle"}]',
  );
  int? _importTeamId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _spielerVorname.dispose();
    _spielerNachname.dispose();
    _spielerEmail.dispose();
    _spielerTelefon.dispose();
    _spielerTtr.dispose();
    _spielerPasswort.dispose();
    _teamName.dispose();
    _teamRang.dispose();
    _teamKlasse.dispose();
    _mitgliedPosition.dispose();
    _mitgliedMeldenummer.dispose();
    _importText.dispose();
    super.dispose();
  }

  Future<_ManagementData> _load() async {
    final api = context.read<ApiClient>();
    final result = await Future.wait([
      api.spieler(),
      api.mannschaften(),
    ]);
    final data = _ManagementData(
      spieler: result[0] as List<Spieler>,
      mannschaften: result[1] as List<Mannschaft>,
    );
    _teamFuehrerId ??= data.spieler.isEmpty ? null : data.spieler.first.id;
    _mitgliedTeamId ??=
        data.mannschaften.isEmpty ? null : data.mannschaften.first.id;
    _mitgliedSpielerId ??= data.spieler.isEmpty ? null : data.spieler.first.id;
    _importTeamId ??=
        data.mannschaften.isEmpty ? null : data.mannschaften.first.id;
    return data;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addSpieler() async {
    try {
      await context.read<ApiClient>().spielerAnlegen(
            vorname: _spielerVorname.text.trim(),
            nachname: _spielerNachname.text.trim(),
            email: _spielerEmail.text.trim(),
            passwort: _spielerPasswort.text,
            telefon: _spielerTelefon.text.trim(),
            ttr: int.tryParse(_spielerTtr.text),
            rolle: _spielerRolle,
            jugend: _spielerJugend,
          );
      _spielerVorname.clear();
      _spielerNachname.clear();
      _spielerEmail.clear();
      _spielerTelefon.clear();
      _spielerTtr.clear();
      _snack('Spieler angelegt.');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addTeam() async {
    try {
      await context.read<ApiClient>().mannschaftAnlegen(
            name: _teamName.text.trim(),
            rang: int.tryParse(_teamRang.text) ?? 1,
            spielklasse: _teamKlasse.text.trim(),
            fuehrerId: _teamFuehrerId,
          );
      _teamName.clear();
      _teamRang.clear();
      _teamKlasse.clear();
      _snack('Mannschaft angelegt.');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addMitglied() async {
    if (_mitgliedTeamId == null || _mitgliedSpielerId == null) return;
    try {
      await context.read<ApiClient>().mitgliedHinzufuegen(
            _mitgliedTeamId!,
            spielerId: _mitgliedSpielerId!,
            standardposition: int.tryParse(_mitgliedPosition.text),
            istStammspieler: _mitgliedStamm,
            meldenummer: _mitgliedMeldenummer.text.trim(),
          );
      _mitgliedPosition.clear();
      _mitgliedMeldenummer.clear();
      _snack('Mitgliedschaft angelegt.');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _copyClickttUrl() async {
    try {
      final data = await context.read<ApiClient>().clickttSpielplanUrl();
      await Clipboard.setData(ClipboardData(text: data['url'] as String));
      _snack('click-TT-Link kopiert.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _importClicktt() async {
    if (_importTeamId == null) return;
    try {
      final decoded = jsonDecode(_importText.text);
      if (decoded is! List) {
        _snack('Import erwartet eine JSON-Liste.');
        return;
      }
      final payload = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final result =
          await context.read<ApiClient>().importClicktt(_importTeamId!, payload);
      _snack('${result['neu']} neu, ${result['aktualisiert']} aktualisiert.');
    } on FormatException {
      _snack('JSON konnte nicht gelesen werden.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isAdmin = auth.spieler?.rolle == Rolle.admin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verwaltung'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<_ManagementData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (!isAdmin)
                  _notice(
                    Icons.lock_outline,
                    'Nur Administratoren koennen Stammdaten speichern. Listen und Kalenderlinks bleiben sichtbar.',
                  ),
                _sectionTitle('Spieler'),
                _spielerForm(isAdmin),
                const SizedBox(height: 12),
                _spielerList(data.spieler),
                const SizedBox(height: 24),
                _sectionTitle('Mannschaften'),
                _teamForm(data, isAdmin),
                const SizedBox(height: 12),
                _teamList(data.mannschaften),
                const SizedBox(height: 24),
                _sectionTitle('Mitgliedschaft und Meldeliste'),
                _mitgliedForm(data, isAdmin),
                const SizedBox(height: 24),
                _sectionTitle('click-TT / myTischtennis'),
                _importForm(data, isAdmin),
                const SizedBox(height: 24),
                _sectionTitle('Kalender und Datenschutz'),
                _calendarAndPrivacy(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _spielerForm(bool enabled) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.person_add_alt,
              title: 'Spieler anlegen',
            ),
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                _field(_spielerVorname, 'Vorname'),
                _field(_spielerNachname, 'Nachname'),
                _field(_spielerEmail, 'E-Mail'),
                _field(_spielerTelefon, 'Telefon'),
                _field(_spielerTtr, 'TTR', number: true),
                _field(_spielerPasswort, 'Passwort'),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<Rolle>(
                    value: _spielerRolle,
                    decoration: const InputDecoration(labelText: 'Rolle'),
                    items: const [
                      DropdownMenuItem(
                          value: Rolle.spieler, child: Text('Spieler')),
                      DropdownMenuItem(
                          value: Rolle.mannschaftsfuehrer,
                          child: Text('Mannschaftsfuehrer')),
                      DropdownMenuItem(
                          value: Rolle.admin, child: Text('Admin')),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _spielerRolle = v!)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jugend'),
                    value: _spielerJugend,
                    onChanged: enabled
                        ? (v) => setState(() => _spielerJugend = v)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled ? _addSpieler : null,
              icon: const Icon(Icons.add),
              label: const Text('Spieler speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamForm(_ManagementData data, bool enabled) {
    final players = data.spieler;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.groups_2_outlined,
              title: 'Mannschaft anlegen',
            ),
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                _field(_teamName, 'Name'),
                _field(_teamRang, 'Rang', number: true),
                _field(_teamKlasse, 'Spielklasse'),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _teamFuehrerId,
                    decoration:
                        const InputDecoration(labelText: 'Mannschaftsfuehrer'),
                    items: players
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (v) => setState(() => _teamFuehrerId = v)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled ? _addTeam : null,
              icon: const Icon(Icons.add),
              label: const Text('Mannschaft speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mitgliedForm(_ManagementData data, bool enabled) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.format_list_numbered,
              title: 'Spieler einer Mannschaft zuordnen',
            ),
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<int>(
                    value: _mitgliedTeamId,
                    decoration: const InputDecoration(labelText: 'Mannschaft'),
                    items: data.mannschaften
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (v) => setState(() => _mitgliedTeamId = v)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _mitgliedSpielerId,
                    decoration: const InputDecoration(labelText: 'Spieler'),
                    items: data.spieler
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (v) => setState(() => _mitgliedSpielerId = v)
                        : null,
                  ),
                ),
                _field(_mitgliedPosition, 'Position', number: true),
                _field(_mitgliedMeldenummer, 'Meldenummer'),
                SizedBox(
                  width: 230,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stammspieler'),
                    value: _mitgliedStamm,
                    onChanged: enabled
                        ? (v) => setState(() => _mitgliedStamm = v)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled ? _addMitglied : null,
              icon: const Icon(Icons.add_link),
              label: const Text('Mitgliedschaft speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importForm(_ManagementData data, bool enabled) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.cloud_download_outlined,
              title: 'Spieltermine importieren',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _importTeamId,
              decoration: const InputDecoration(labelText: 'Zielmannschaft'),
              items: data.mannschaften
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  enabled ? (v) => setState(() => _importTeamId = v) : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _importText,
              minLines: 4,
              maxLines: 8,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Importdaten als JSON-Liste',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? _importClicktt : null,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import uebernehmen'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyClickttUrl,
                  icon: const Icon(Icons.link),
                  label: const Text('click-TT-Link kopieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarAndPrivacy(_ManagementData data) {
    final auth = context.watch<AuthState>();
    final selected = auth.spieler;
    final api = context.read<ApiClient>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              icon: Icons.security_outlined,
              title: 'Kalenderlink und Sichtbarkeit',
            ),
            const SizedBox(height: 12),
            if (selected != null)
              SelectableText(
                api.icalUrl(selected.id),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            Text(
              'Telefonnummern und Spielerdaten werden in der App nur nach Login geladen. Fuer eine produktive DSGVO-Umsetzung fehlen noch nicht-erratbare Kalender-Tokens, Einwilligungsstatus und Datenexport.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spielerList(List<Spieler> players) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < players.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(child: Text(players[i].id.toString())),
              title: Text(players[i].name),
              subtitle: Text(
                '${players[i].email} · ${players[i].status} · TTR ${players[i].ttr ?? '-'}',
              ),
              trailing: _roleBadge(players[i].rolle),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamList(List<Mannschaft> teams) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < teams.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(child: Text('${teams[i].rang}')),
              title: Text(teams[i].name),
              subtitle: Text(teams[i].spielklasse ?? 'Keine Spielklasse'),
              trailing: teams[i].fuehrerId == null
                  ? const Text('ohne Fuehrer')
                  : Text('Fuehrer #${teams[i].fuehrerId}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool number = false}) {
    return SizedBox(
      width: 210,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _notice(IconData icon, String text) {
    return Card(
      color: AppColors.brand.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(Rolle role) {
    final label = switch (role) {
      Rolle.admin => 'Admin',
      Rolle.mannschaftsfuehrer => 'Fuehrer',
      Rolle.spieler => 'Spieler',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }
}

class _ManagementData {
  const _ManagementData({required this.spieler, required this.mannschaften});

  final List<Spieler> spieler;
  final List<Mannschaft> mannschaften;
}
