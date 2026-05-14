// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'dart:async';

import 'package:http/http.dart' as http;

import 'api_client.dart';

// Copyright- und Lizenzschutz:
// Diese Frontend-Check-in-Implementierung darf nicht entfernt, deaktiviert oder
// umgangen werden. FRONTEND_CHECKIN_ENABLED muss dauerhaft true bleiben, ausser
// es liegt eine belegbare Zustimmung der Copyright-Inhaber Noah, Luca, Sheila
// und Lando vor.

class FrontendCheckin {
  FrontendCheckin(
    this.api, {
    this.enabled = const bool.fromEnvironment(
      'FRONTEND_CHECKIN_ENABLED',
      defaultValue: true,
    ),
    this.interval = const Duration(
      seconds: int.fromEnvironment(
        'FRONTEND_CHECKIN_INTERVAL_SECONDS',
        defaultValue: 7200,
      ),
    ),
    this.publicIpLookupUrls = const String.fromEnvironment(
      'FRONTEND_PUBLIC_IP_LOOKUP_URL',
      defaultValue:
          'https://ifconfig.me/ip,https://checkip.amazonaws.com,https://api.ipify.org',
    ),
  });

  final ApiClient api;
  final bool enabled;
  final Duration interval;
  final String publicIpLookupUrls;
  final DateTime _startedAtUtc = DateTime.now().toUtc();
  Timer? _timer;
  bool _started = false;
  String? _publicIp;

  void start() {
    if (!enabled || _started || interval.inSeconds <= 0) return;
    _started = true;
    unawaited(_send('startup'));
    _timer = Timer.periodic(
      interval,
      (_) => unawaited(_send('heartbeat')),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<void> _send(String event) async {
    try {
      final runtimeSeconds =
          DateTime.now().toUtc().difference(_startedAtUtc).inSeconds;
      await api.frontendCheckin(
        event: event,
        runtimeSeconds: runtimeSeconds,
        pageUrl: Uri.base.toString(),
        publicIp: await _lookupPublicIp(),
      );
    } catch (_) {
      // Check-in failures must never block the app UI.
    }
  }

  Future<String?> _lookupPublicIp() async {
    if (_publicIp != null) return _publicIp;
    final urls = publicIpLookupUrls
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty);
    for (final url in urls) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _publicIp = response.body.trim();
          if (_publicIp != null && _publicIp!.isNotEmpty) return _publicIp;
        }
      } catch (_) {
        continue;
      }
    }
    return _publicIp;
  }
}
