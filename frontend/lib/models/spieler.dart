// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

enum Rolle { admin, mannschaftsfuehrer, spieler }

Rolle rolleFromString(String s) {
  switch (s) {
    case 'admin':
      return Rolle.admin;
    case 'mannschaftsfuehrer':
      return Rolle.mannschaftsfuehrer;
    default:
      return Rolle.spieler;
  }
}

class Spieler {
  final int id;
  final String vorname;
  final String nachname;
  final String email;
  final String? telefon;
  final int? ttr;
  final Rolle rolle;
  final String status;
  final bool jugend;

  Spieler({
    required this.id,
    required this.vorname,
    required this.nachname,
    required this.email,
    this.telefon,
    this.ttr,
    required this.rolle,
    required this.status,
    this.jugend = false,
  });

  String get name => '$vorname $nachname';

  factory Spieler.fromJson(Map<String, dynamic> j) => Spieler(
        id: j['id'] as int,
        vorname: j['vorname'] as String,
        nachname: j['nachname'] as String,
        email: j['email'] as String,
        telefon: j['telefon'] as String?,
        ttr: j['ttr'] as int?,
        rolle: rolleFromString(j['rolle'] as String),
        status: j['status'] as String,
        jugend: j['jugend'] as bool? ?? false,
      );
}
