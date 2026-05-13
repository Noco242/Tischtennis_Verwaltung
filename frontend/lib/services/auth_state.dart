import 'package:flutter/foundation.dart';

import '../models/spieler.dart';
import 'api_client.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final ApiClient api;
  Spieler? _spieler;
  bool _loading = false;
  String? _error;

  Spieler? get spieler => _spieler;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => api.isLoggedIn;

  Future<void> init() async {
    await api.ladeSession();
    if (api.isLoggedIn) {
      try {
        _spieler = await api.me();
      } catch (_) {
        await api.logout();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String passwort) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await api.login(email, passwort);
      _spieler = await api.me();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.logout();
    _spieler = null;
    notifyListeners();
  }
}
