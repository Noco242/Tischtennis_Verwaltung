// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/spiel.dart';
import '../models/spieler.dart';
import '../services/api_client.dart';
import '../theme.dart';

class PinResponseScreen extends StatefulWidget {
  const PinResponseScreen({super.key});

  @override
  State<PinResponseScreen> createState() => _PinResponseScreenState();
}

class _PinResponseScreenState extends State<PinResponseScreen> {
  late Future<_PinData> _future;
  final _pin = TextEditingController();
  int? _spielId;
  int? _spielerId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<_PinData> _load() async {
    final api = context.read<ApiClient>();
    final result = await Future.wait([
      api.meineSpiele(),
      api.spieler(),
    ]);
    final data = _PinData(
      spiele: result[0] as List<Spiel>,
      spieler: result[1] as List<Spieler>,
    );
    _spielId ??= data.spiele.isEmpty ? null : data.spiele.first.id;
    _spielerId ??= api.spielerId;
    _spielerId ??= data.spieler.isEmpty ? null : data.spieler.first.id;
    return data;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send(ZusageStatus status) async {
    if (_spielId == null || _spielerId == null) return;
    try {
      await context.read<ApiClient>().zusageViaPin(
            spielId: _spielId!,
            pin: _pin.text.trim(),
            spielerId: _spielerId!,
            status: status,
          );
      _snack(status == ZusageStatus.zugesagt
          ? 'Zusage per PIN gespeichert.'
          : 'Absage per PIN gespeichert.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd.MM.yyyy HH:mm', 'de_DE');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiel-PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<_PinData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.vpn_key_outlined,
                                color: AppColors.brand),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Rueckmeldung ohne Voll-Login',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        value: _spielId,
                        decoration: const InputDecoration(labelText: 'Spiel'),
                        items: data.spiele
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${df.format(s.termin)} - ${s.gegner}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _spielId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _spielerId,
                        decoration: const InputDecoration(labelText: 'Spieler'),
                        items: data.spieler
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _spielerId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'PIN'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _send(ZusageStatus.zugesagt),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Zusagen'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _send(ZusageStatus.abgesagt),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Absagen'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.statusAbgesagt,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PinData {
  const _PinData({required this.spiele, required this.spieler});

  final List<Spiel> spiele;
  final List<Spieler> spieler;
}
