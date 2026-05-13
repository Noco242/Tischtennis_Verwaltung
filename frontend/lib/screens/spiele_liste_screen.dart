// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/spiel.dart';
import '../services/api_client.dart';
import '../services/auth_state.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'spiel_detail_screen.dart';

class SpieleListeScreen extends StatefulWidget {
  const SpieleListeScreen({super.key});

  @override
  State<SpieleListeScreen> createState() => _SpieleListeScreenState();
}

class _SpieleListeScreenState extends State<SpieleListeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd.MM.yyyy • HH:mm', 'de_DE');
    final auth = context.watch<AuthState>();
    final spielerId = auth.spieler?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Spiele'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Spiel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Fehler: ${snap.error}'));
            }
            final spiele = (snap.data ?? [])
              ..sort((a, b) => a.termin.compareTo(b.termin));
            if (spiele.isEmpty) {
              return const Center(child: Text('Keine Spiele.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: spiele.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = spiele[i];
                return Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SpielDetailScreen(spielId: s.id),
                        ),
                      );
                      _refresh();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: s.istHeimspiel
                                  ? AppColors.brand.withOpacity(0.1)
                                  : AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.istHeimspiel ? 'H' : 'A',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: s.istHeimspiel
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'vs ${s.gegner}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (s.aufstellungFreigegeben)
                                      const Icon(
                                        Icons.lock_clock,
                                        color: AppColors.statusZugesagt,
                                        size: 18,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  df.format(s.termin),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (s.ort != null)
                                  Text(
                                    s.ort!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 6),
                                StatusChip(
                                  status: _eigeneZusage(s, spielerId),
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFB0B4C0),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
