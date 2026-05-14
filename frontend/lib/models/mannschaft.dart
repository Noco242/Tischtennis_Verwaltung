// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

class Mannschaft {
  final int id;
  final String name;
  final int rang;
  final String? spielklasse;
  final int? fuehrerId;

  Mannschaft({
    required this.id,
    required this.name,
    required this.rang,
    this.spielklasse,
    this.fuehrerId,
  });

  factory Mannschaft.fromJson(Map<String, dynamic> j) => Mannschaft(
        id: j['id'] as int,
        name: j['name'] as String,
        rang: j['rang'] as int,
        spielklasse: j['spielklasse'] as String?,
        fuehrerId: j['fuehrer_id'] as int?,
      );
}
