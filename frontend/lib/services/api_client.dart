import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mannschaft.dart';
import '../models/spiel.dart';
import '../models/spieler.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:8000'});

  final String baseUrl;
  String? _token;
  int? _spielerId;
  Rolle? _rolle;

  String? get token => _token;
  int? get spielerId => _spielerId;
  Rolle? get rolle => _rolle;
  bool get isLoggedIn => _token != null;

  Future<void> ladeSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _spielerId = prefs.getInt('spielerId');
    final rolleStr = prefs.getString('rolle');
    if (rolleStr != null) _rolle = rolleFromString(rolleStr);
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('token', _token!);
    if (_spielerId != null) await prefs.setInt('spielerId', _spielerId!);
    if (_rolle != null) await prefs.setString('rolle', _rolle!.name);
  }

  Future<void> logout() async {
    _token = null;
    _spielerId = null;
    _rolle = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('spielerId');
    await prefs.remove('rolle');
  }

  Map<String, String> _headers({bool auth = true}) {
    final h = {'Content-Type': 'application/json'};
    if (auth && _token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _send(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(r.body);
    }
    String msg = r.body;
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) msg = j['detail'].toString();
    } catch (_) {}
    throw ApiException(r.statusCode, msg);
  }

  Future<void> login(String email, String passwort) async {
    final r = await http.post(
      _u('/auth/login'),
      headers: _headers(auth: false),
      body: jsonEncode({'email': email, 'passwort': passwort}),
    );
    final data = await _send(r) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    _spielerId = data['spieler_id'] as int;
    _rolle = rolleFromString(data['rolle'] as String);
    await _saveSession();
  }

  Future<Spieler> me() async {
    final r = await http.get(_u('/auth/me'), headers: _headers());
    return Spieler.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<List<Spiel>> meineSpiele() async {
    final r = await http.get(_u('/spiele/meine'), headers: _headers());
    final list = await _send(r) as List;
    return list.map((e) => Spiel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Spiel> spielDetail(int id) async {
    final r = await http.get(_u('/spiele/$id'), headers: _headers());
    return Spiel.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<void> setzeZusage(int spielId, ZusageStatus status, {String? kommentar}) async {
    final r = await http.post(
      _u('/spiele/$spielId/zusage'),
      headers: _headers(),
      body: jsonEncode({
        'status': zusageStatusToApi(status),
        if (kommentar != null) 'kommentar': kommentar,
      }),
    );
    await _send(r);
  }

  Future<void> setzeTreffpunkt(int spielId,
      {String? ort, DateTime? zeit, String? notiz}) async {
    final r = await http.post(
      _u('/spiele/$spielId/treffpunkt'),
      headers: _headers(),
      body: jsonEncode({
        if (ort != null) 'treffpunkt_ort': ort,
        if (zeit != null) 'treffpunkt_zeit': zeit.toIso8601String(),
        if (notiz != null) 'notiz': notiz,
      }),
    );
    await _send(r);
  }

  Future<List<Mannschaft>> mannschaften() async {
    final r = await http.get(_u('/mannschaften'), headers: _headers());
    final list = await _send(r) as List;
    return list.map((e) => Mannschaft.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Spieler>> spieler() async {
    final r = await http.get(_u('/spieler'), headers: _headers());
    final list = await _send(r) as List;
    return list.map((e) => Spieler.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Spieler> spielerAnlegen({
    required String vorname,
    required String nachname,
    required String email,
    required String passwort,
    String? telefon,
    int? ttr,
    Rolle rolle = Rolle.spieler,
    bool jugend = false,
  }) async {
    final r = await http.post(
      _u('/spieler'),
      headers: _headers(),
      body: jsonEncode({
        'vorname': vorname,
        'nachname': nachname,
        'email': email,
        'passwort': passwort,
        if (telefon != null && telefon.isNotEmpty) 'telefon': telefon,
        if (ttr != null) 'ttr': ttr,
        'rolle': rolle.name,
        'jugend': jugend,
      }),
    );
    return Spieler.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<Spieler> spielerAktualisieren(
    int spielerId, {
    String? vorname,
    String? nachname,
    String? email,
    String? telefon,
    int? ttr,
    Rolle? rolle,
    String? status,
    bool? jugend,
  }) async {
    final r = await http.patch(
      _u('/spieler/$spielerId'),
      headers: _headers(),
      body: jsonEncode({
        if (vorname != null) 'vorname': vorname,
        if (nachname != null) 'nachname': nachname,
        if (email != null) 'email': email,
        if (telefon != null) 'telefon': telefon,
        if (ttr != null) 'ttr': ttr,
        if (rolle != null) 'rolle': rolle.name,
        if (status != null) 'status': status,
        if (jugend != null) 'jugend': jugend,
      }),
    );
    return Spieler.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<Mannschaft> mannschaftAnlegen({
    required String name,
    required int rang,
    String? spielklasse,
    int? fuehrerId,
  }) async {
    final r = await http.post(
      _u('/mannschaften'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'rang': rang,
        if (spielklasse != null && spielklasse.isNotEmpty)
          'spielklasse': spielklasse,
        if (fuehrerId != null) 'fuehrer_id': fuehrerId,
      }),
    );
    return Mannschaft.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<Mannschaft> mannschaftAktualisieren(
    int mannschaftId, {
    String? name,
    int? rang,
    String? spielklasse,
    int? fuehrerId,
  }) async {
    final r = await http.patch(
      _u('/mannschaften/$mannschaftId'),
      headers: _headers(),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (rang != null) 'rang': rang,
        if (spielklasse != null) 'spielklasse': spielklasse,
        if (fuehrerId != null) 'fuehrer_id': fuehrerId,
      }),
    );
    return Mannschaft.fromJson(await _send(r) as Map<String, dynamic>);
  }

  Future<void> mitgliedHinzufuegen(
    int mannschaftId, {
    required int spielerId,
    int? standardposition,
    bool istStammspieler = true,
    String? meldenummer,
  }) async {
    final r = await http.post(
      _u('/mannschaften/$mannschaftId/mitglieder'),
      headers: _headers(),
      body: jsonEncode({
        'spieler_id': spielerId,
        if (standardposition != null) 'standardposition': standardposition,
        'ist_stammspieler': istStammspieler,
        if (meldenummer != null && meldenummer.isNotEmpty)
          'meldenummer': meldenummer,
      }),
    );
    await _send(r);
  }

  Future<Map<String, dynamic>> aufstellungValidieren(
    int spielId,
    List<AufstellungEintrag> eintraege, {
    bool freigeben = false,
  }) async {
    final r = await http.post(
      _u('/spiele/$spielId/aufstellung/validieren'),
      headers: _headers(),
      body: jsonEncode({
        'eintraege': eintraege.map((e) => e.toJson()).toList(),
        'freigeben': freigeben,
      }),
    );
    return await _send(r) as Map<String, dynamic>;
  }

  Future<void> aufstellungSetzen(
    int spielId,
    List<AufstellungEintrag> eintraege, {
    bool freigeben = false,
  }) async {
    final r = await http.put(
      _u('/spiele/$spielId/aufstellung'),
      headers: _headers(),
      body: jsonEncode({
        'eintraege': eintraege.map((e) => e.toJson()).toList(),
        'freigeben': freigeben,
      }),
    );
    await _send(r);
  }

  Future<Map<String, dynamic>?> ersatzNaechster(
    int spielId, {
    required int position,
  }) async {
    final r = await http.post(
      _u('/spiele/$spielId/ersatz-naechster'),
      headers: _headers(),
      body: jsonEncode({'position': position}),
    );
    final body = await _send(r);
    return body == null ? null : body as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> ersatzanfragen(int spielId) async {
    final r = await http.get(
      _u('/spiele/$spielId/ersatzanfragen'),
      headers: _headers(),
    );
    final list = await _send(r) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> zusageViaPin({
    required int spielId,
    required String pin,
    required int spielerId,
    required ZusageStatus status,
  }) async {
    final r = await http.post(
      _u('/spiele/$spielId/zusage-pin'),
      headers: _headers(auth: false),
      body: jsonEncode({
        'pin': pin,
        'spieler_id': spielerId,
        'status': zusageStatusToApi(status),
      }),
    );
    await _send(r);
  }

  Future<Map<String, dynamic>> clickttSpielplanUrl({
    String verband = 'BaTTV',
    String saison = '25--26',
    int vereinId = 1012,
    String vereinsname = 'FC 1932 e.V. Külsheim',
  }) async {
    final query = Uri(queryParameters: {
      'verband': verband,
      'saison': saison,
      'verein_id': '$vereinId',
      'vereinsname': vereinsname,
    }).query;
    final r = await http.get(
      _u('/clicktt/spielplan-url?$query'),
      headers: _headers(),
    );
    return await _send(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importClicktt(
    int mannschaftId,
    List<Map<String, dynamic>> spiele,
  ) async {
    final r = await http.post(
      _u('/import/clicktt/$mannschaftId'),
      headers: _headers(),
      body: jsonEncode(spiele),
    );
    return await _send(r) as Map<String, dynamic>;
  }

  String icalUrl(int spielerId) => '$baseUrl/ical/$spielerId.ics';
}
