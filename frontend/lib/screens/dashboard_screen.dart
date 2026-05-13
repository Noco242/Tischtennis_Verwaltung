// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/spiel.dart';
import '../models/spieler.dart';
import '../services/api_client.dart';
import '../services/auth_state.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'management_screen.dart';
import 'pin_response_screen.dart';
import 'spiel_detail_screen.dart';
import 'spiele_liste_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Spiel>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().meineSpiele();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<ApiClient>().meineSpiele();
    });
  }

  ZusageStatus _eigeneZusage(Spiel s, int spielerId) {
    for (final z in s.zusagen) {
      if (z.spielerId == spielerId) return z.status;
    }
    return ZusageStatus.offen;
  }

  Future<void> _zusagen(Spiel s, ZusageStatus status) async {
    try {
      await context.read<ApiClient>().setzeZusage(s.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == ZusageStatus.zugesagt
              ? 'Du hast zugesagt.'
              : 'Du hast abgesagt.'),
        ),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final spielerId = auth.spieler?.id ?? 0;
    final df = DateFormat('EEE, dd.MM. HH:mm', 'de_DE');
    final name = auth.spieler?.vorname ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Spiel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _Header(
                    name: name,
                    showManagement: auth.spieler?.rolle == Rolle.admin ||
                        auth.spieler?.rolle == Rolle.mannschaftsfuehrer,
                    onManagement: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManagementScreen(),
                      ),
                    ).then((_) => _refresh()),
                    onPin: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PinResponseScreen(),
                      ),
                    ).then((_) => _refresh()),
                    onCalendar: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SpieleListeScreen(),
                      ),
                    ).then((_) => _refresh()),
                    onLogout: () => auth.logout(),
                  ),
                  const SizedBox(height: 20),
                  if (snap.hasError)
                    _ErrorCard(message: '${snap.error}')
                  else
                    ..._buildSpieleListe(
                      context,
                      snap.data ?? [],
                      spielerId,
                      df,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpieleListe(
    BuildContext context,
    List<Spiel> alle,
    int spielerId,
    DateFormat df,
  ) {
    final spiele = alle
        .where((s) =>
            s.termin.isAfter(DateTime.now().subtract(const Duration(hours: 6))))
        .toList()
      ..sort((a, b) => a.termin.compareTo(b.termin));

    if (spiele.isEmpty) {
      return const [_EmptyCard()];
    }

    final next = spiele.first;
    final eigene = _eigeneZusage(next, spielerId);
    final zugesagt =
        next.zusagen.where((z) => z.status == ZusageStatus.zugesagt).length;
    final abgesagt =
        next.zusagen.where((z) => z.status == ZusageStatus.abgesagt).length;
    final offen =
        next.zusagen.where((z) => z.status == ZusageStatus.offen).length;

    return [
      _NaechstesSpielCard(
        spiel: next,
        zugesagt: zugesagt,
        abgesagt: abgesagt,
        offen: offen,
        eigeneZusage: eigene,
        df: df,
        onZusagen: () => _zusagen(next, ZusageStatus.zugesagt),
        onAbsagen: () => _zusagen(next, ZusageStatus.abgesagt),
        onDetail: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpielDetailScreen(spielId: next.id),
            ),
          );
          _refresh();
        },
        onNavigieren: () async {
          if (next.ort == null) return;
          final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(next.ort!)}',
          );
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
      if (spiele.length > 1) ...[
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Weitere Spiele',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 12),
        for (final s in spiele.skip(1).take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SpielListItem(
              spiel: s,
              df: df,
              eigeneZusage: _eigeneZusage(s, spielerId),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpielDetailScreen(spielId: s.id),
                  ),
                );
                _refresh();
              },
            ),
          ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.showManagement,
    required this.onManagement,
    required this.onPin,
    required this.onCalendar,
    required this.onLogout,
  });

  final String name;
  final bool showManagement;
  final VoidCallback onManagement;
  final VoidCallback onPin;
  final VoidCallback onCalendar;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hallo${name.isNotEmpty ? ", $name" : ""}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Dein Dashboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        if (showManagement) ...[
          _IconBtn(icon: Icons.admin_panel_settings_outlined, onTap: onManagement),
          const SizedBox(width: 8),
        ],
        _IconBtn(icon: Icons.vpn_key_outlined, onTap: onPin),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.calendar_month_outlined, onTap: onCalendar),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.logout, onTap: onLogout),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available,
                  color: AppColors.brand, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keine kommenden Spiele',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sobald neue Spieltermine gesetzt sind, erscheinen sie hier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.statusAbgesagt),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _NaechstesSpielCard extends StatelessWidget {
  const _NaechstesSpielCard({
    required this.spiel,
    required this.zugesagt,
    required this.abgesagt,
    required this.offen,
    required this.eigeneZusage,
    required this.df,
    required this.onZusagen,
    required this.onAbsagen,
    required this.onDetail,
    required this.onNavigieren,
  });

  final Spiel spiel;
  final int zugesagt;
  final int abgesagt;
  final int offen;
  final ZusageStatus eigeneZusage;
  final DateFormat df;
  final VoidCallback onZusagen;
  final VoidCallback onAbsagen;
  final VoidCallback onDetail;
  final VoidCallback onNavigieren;

  @override
  Widget build(BuildContext context) {
    final daysUntil = spiel.termin.difference(DateTime.now()).inDays;
    final inLabel = daysUntil <= 0
        ? 'Heute'
        : daysUntil == 1
            ? 'Morgen'
            : 'In $daysUntil Tagen';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brand],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(inLabel),
                const SizedBox(width: 8),
                _badge(spiel.istHeimspiel ? 'HEIM' : 'AUSWÄRTS'),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Nächstes Spiel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'vs ${spiel.gegner}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.event_outlined, df.format(spiel.termin)),
            if (spiel.ort != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.place_outlined,
                    size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spiel.ort!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton.icon(
                  onPressed: onNavigieren,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Navi'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.18),
                  ),
                ),
              ]),
            ],
            if (spiel.treffpunktOrt != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.group_outlined,
                'Treffpunkt: ${spiel.treffpunktOrt}'
                '${spiel.treffpunktZeit != null ? " um ${DateFormat('HH:mm').format(spiel.treffpunktZeit!)}" : ""}',
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _countPill(
                          AppColors.statusZugesagt, 'Zugesagt', zugesagt),
                      const SizedBox(width: 8),
                      _countPill(AppColors.statusAbgesagt, 'Abgesagt', abgesagt),
                      const SizedBox(width: 8),
                      _countPill(AppColors.statusOffen, 'Offen', offen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Dein Status:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(status: eigeneZusage),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Details & Aufstellung'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _countPill(Color color, String label, int n) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpielListItem extends StatelessWidget {
  const _SpielListItem({
    required this.spiel,
    required this.df,
    required this.eigeneZusage,
    required this.onTap,
  });

  final Spiel spiel;
  final DateFormat df;
  final ZusageStatus eigeneZusage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spiel.istHeimspiel
                      ? AppColors.brand.withOpacity(0.1)
                      : AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  spiel.istHeimspiel ? 'H' : 'A',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: spiel.istHeimspiel
                        ? AppColors.brand
                        : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${spiel.gegner}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${df.format(spiel.termin)}${spiel.ort != null ? " • ${spiel.ort}" : ""}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: eigeneZusage, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
