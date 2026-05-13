import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/spiel.dart';
import '../models/spieler.dart';
import '../services/api_client.dart';
import '../services/auth_state.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';

class SpielDetailScreen extends StatefulWidget {
  const SpielDetailScreen({required this.spielId, super.key});

  final int spielId;

  @override
  State<SpielDetailScreen> createState() => _SpielDetailScreenState();
}

class _SpielDetailScreenState extends State<SpielDetailScreen> {
  late Future<Spiel> _future;
  Future<List<Spieler>>? _spielerFuture;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().spielDetail(widget.spielId);
  }

  void _refresh() {
    setState(() {
      _future = context.read<ApiClient>().spielDetail(widget.spielId);
    });
  }

  Future<void> _zusagen(ZusageStatus status) async {
    try {
      await context.read<ApiClient>().setzeZusage(widget.spielId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == ZusageStatus.zugesagt
              ? 'Du hast zugesagt.'
              : 'Du hast abgesagt.'),
        ),
      );
      _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _treffpunktSetzen(Spiel s) async {
    final ortCtl = TextEditingController(text: s.treffpunktOrt ?? '');
    final notizCtl = TextEditingController(text: s.notiz ?? '');
    DateTime? zeit = s.treffpunktZeit;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Treffpunkt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ortCtl,
                decoration: const InputDecoration(
                  labelText: 'Ort',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notizCtl,
                decoration: const InputDecoration(
                  labelText: 'Notiz / Wer kommt direkt?',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(zeit == null
                      ? 'Zeit wählen'
                      : DateFormat('dd.MM. HH:mm', 'de_DE').format(zeit!)),
                  onTap: () async {
                    final initial =
                        zeit ?? s.termin.subtract(const Duration(hours: 1));
                    final date = await showDatePicker(
                      context: ctx,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: initial,
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(initial),
                    );
                    if (time == null) return;
                    setStateLocal(() {
                      zeit = DateTime(date.year, date.month, date.day,
                          time.hour, time.minute);
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                await context.read<ApiClient>().setzeTreffpunkt(
                       widget.spielId,
                       ort: ortCtl.text.isEmpty ? null : ortCtl.text,
                       zeit: zeit,
                       notiz: notizCtl.text.isEmpty ? null : notizCtl.text,
                     );
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aufstellungBearbeiten(Spiel s) async {
    final api = context.read<ApiClient>();
    final alleSpieler = await api.spieler();
    if (alleSpieler.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Spieler vorhanden.')),
      );
      return;
    }
    final selected = List<int?>.generate(
      4,
      (index) => index < s.aufstellung.length
          ? s.aufstellung[index].spielerId
          : (alleSpieler.isNotEmpty ? alleSpieler.first.id : null),
    );
    var freigeben = s.aufstellungFreigegeben;
    List<String> warnungen = [];
    List<String> fehler = [];

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateLocal) {
          final eintraege = List.generate(
            4,
            (index) => AufstellungEintrag(
              position: index + 1,
              spielerId: selected[index] ?? alleSpieler.first.id,
            ),
          );
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Aufstellung bearbeiten'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    DropdownButtonFormField<int>(
                      value: selected[i],
                      decoration: InputDecoration(labelText: 'Position ${i + 1}'),
                      items: alleSpieler
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} · TTR ${p.ttr ?? '-'}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateLocal(() => selected[i] = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Direkt freigeben'),
                    value: freigeben,
                    onChanged: (v) => setStateLocal(() => freigeben = v),
                  ),
                  for (final text in warnungen)
                    _dialogMessage(text, AppColors.statusOffen),
                  for (final text in fehler)
                    _dialogMessage(text, AppColors.statusAbgesagt),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen')),
              TextButton(
                onPressed: () async {
                  final result = await api.aufstellungValidieren(
                    widget.spielId,
                    eintraege,
                    freigeben: freigeben,
                  );
                  setStateLocal(() {
                    warnungen = (result['warnungen'] as List? ?? [])
                        .map((e) => '$e')
                        .toList();
                    fehler = (result['fehler'] as List? ?? [])
                        .map((e) => '$e')
                        .toList();
                  });
                },
                child: const Text('Validieren'),
              ),
              FilledButton(
                onPressed: () async {
                  await api.aufstellungSetzen(
                    widget.spielId,
                    eintraege,
                    freigeben: freigeben,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refresh();
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogMessage(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  Future<void> _ersatzAnfragen(Spiel s) async {
    if (s.aufstellung.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Es gibt noch keine Aufstellung.')),
      );
      return;
    }
    var position = s.aufstellung.first.position;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ersatzspieler anfragen'),
          content: DropdownButtonFormField<int>(
            value: position,
            decoration: const InputDecoration(labelText: 'Position'),
            items: s.aufstellung
                .map(
                  (e) => DropdownMenuItem(
                    value: e.position,
                    child: Text('Position ${e.position}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setStateLocal(() => position = v ?? position),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                await context
                    .read<ApiClient>()
                    .ersatzNaechster(widget.spielId, position: position);
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('Anfragen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final df = DateFormat('EEE, dd.MM.yyyy • HH:mm', 'de_DE');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiel-Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Spiel>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final s = snap.data!;
          final eigeneZusage = s.zusagen
                  .where((z) => z.spielerId == auth.spieler?.id)
                  .map((z) => z.status)
                  .firstOrNull ??
              ZusageStatus.offen;
          final istFuehrerOderAdmin = auth.spieler?.rolle == Rolle.admin ||
              auth.spieler?.rolle == Rolle.mannschaftsfuehrer;
          final zugesagt =
              s.zusagen.where((z) => z.status == ZusageStatus.zugesagt).length;
          final abgesagt =
              s.zusagen.where((z) => z.status == ZusageStatus.abgesagt).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _HeaderCard(spiel: s, df: df),
              const SizedBox(height: 16),
              _ZusageActionCard(
                eigeneZusage: eigeneZusage,
                zugesagt: zugesagt,
                abgesagt: abgesagt,
                onZusagen: () => _zusagen(ZusageStatus.zugesagt),
                onAbsagen: () => _zusagen(ZusageStatus.abgesagt),
              ),
              if (istFuehrerOderAdmin) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_location_alt,
                              color: AppColors.brand, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Treffpunkt festlegen',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _treffpunktSetzen(s),
                          child: const Text('Öffnen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _aufstellungBearbeiten(s),
                            icon: const Icon(Icons.format_list_numbered),
                            label: const Text('Aufstellung'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _ersatzAnfragen(s),
                            icon: const Icon(Icons.person_search),
                            label: const Text('Ersatz'),
                          ),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _SectionTitle('Aufstellung'),
              const SizedBox(height: 10),
              if (s.aufstellung.isEmpty)
                _emptyHint('Noch keine Aufstellung festgelegt.')
              else
                _aufstellungBlock(context, s),
              const SizedBox(height: 24),
              const _SectionTitle('Rückmeldungen'),
              const SizedBox(height: 10),
              if (s.zusagen.isEmpty)
                _emptyHint('Bisher keine Rückmeldungen.')
              else
                _zusagenBlock(context, s),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aufstellungBlock(BuildContext context, Spiel s) {
    _spielerFuture ??= context.read<ApiClient>().spieler();
    return FutureBuilder<List<Spieler>>(
      future: _spielerFuture,
      builder: (ctx, snap) {
        final byId = {for (final p in snap.data ?? <Spieler>[]) p.id: p};
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < s.aufstellung.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    radius: 18,
                    child: Text(
                      '${s.aufstellung[i].position}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    byId[s.aufstellung[i].spielerId]?.name ??
                        'Spieler #${s.aufstellung[i].spielerId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: byId[s.aufstellung[i].spielerId]?.ttr != null
                      ? Text(
                          'TTR ${byId[s.aufstellung[i].spielerId]!.ttr}',
                          style: const TextStyle(color: AppColors.textMuted),
                        )
                      : null,
                  trailing: s.aufstellung[i].istErsatz
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Ersatz',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _zusagenBlock(BuildContext context, Spiel s) {
    _spielerFuture ??= context.read<ApiClient>().spieler();
    return FutureBuilder<List<Spieler>>(
      future: _spielerFuture,
      builder: (ctx, snap) {
        final byId = {for (final p in snap.data ?? <Spieler>[]) p.id: p};
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < s.zusagen.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text(
                    byId[s.zusagen[i].spielerId]?.name ??
                        'Spieler #${s.zusagen[i].spielerId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: s.zusagen[i].kommentar != null
                      ? Text(s.zusagen[i].kommentar!)
                      : null,
                  trailing:
                      StatusChip(status: s.zusagen[i].status, compact: true),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.spiel, required this.df});
  final Spiel spiel;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brand],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              spiel.istHeimspiel ? 'HEIMSPIEL' : 'AUSWÄRTSSPIEL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'vs ${spiel.gegner}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          _row(Icons.event_outlined, df.format(spiel.termin)),
          if (spiel.ort != null) ...[
            const SizedBox(height: 8),
            _row(Icons.place_outlined, spiel.ort!),
          ],
          if (spiel.treffpunktOrt != null) ...[
            const SizedBox(height: 8),
            _row(
              Icons.group_outlined,
              'Treffpunkt: ${spiel.treffpunktOrt}'
              '${spiel.treffpunktZeit != null ? " um ${DateFormat('HH:mm').format(spiel.treffpunktZeit!)}" : ""}',
            ),
          ],
          if (spiel.notiz != null) ...[
            const SizedBox(height: 8),
            _row(Icons.notes_outlined, spiel.notiz!),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ],
    );
  }
}

class _ZusageActionCard extends StatelessWidget {
  const _ZusageActionCard({
    required this.eigeneZusage,
    required this.zugesagt,
    required this.abgesagt,
    required this.onZusagen,
    required this.onAbsagen,
  });

  final ZusageStatus eigeneZusage;
  final int zugesagt;
  final int abgesagt;
  final VoidCallback onZusagen;
  final VoidCallback onAbsagen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Deine Antwort',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                StatusChip(status: eigeneZusage),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Zusagen'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.statusZugesagt,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.statusZugesagt.withOpacity(0.35),
                      disabledForegroundColor: Colors.white,
                    ),
                    onPressed: eigeneZusage == ZusageStatus.zugesagt
                        ? null
                        : onZusagen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Absagen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusAbgesagt,
                      side: BorderSide(
                        color: eigeneZusage == ZusageStatus.abgesagt
                            ? AppColors.statusAbgesagt.withOpacity(0.4)
                            : AppColors.statusAbgesagt,
                        width: 1.4,
                      ),
                    ),
                    onPressed: eigeneZusage == ZusageStatus.abgesagt
                        ? null
                        : onAbsagen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    AppColors.statusZugesagt,
                    Icons.check_circle,
                    'Zusagen',
                    zugesagt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    AppColors.statusAbgesagt,
                    Icons.cancel,
                    'Absagen',
                    abgesagt,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(Color color, IconData icon, String label, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$n',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

extension on Iterable<ZusageStatus> {
  ZusageStatus? get firstOrNull => isEmpty ? null : first;
}
