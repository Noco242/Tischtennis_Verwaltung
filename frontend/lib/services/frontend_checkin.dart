// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'dart:async';

import 'api_client.dart';

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
  });

  final ApiClient api;
  final bool enabled;
  final Duration interval;
  final DateTime _startedAtUtc = DateTime.now().toUtc();
  Timer? _timer;
  bool _started = false;

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
      );
    } catch (_) {
      // Check-in failures must never block the app UI.
    }
  }
}
