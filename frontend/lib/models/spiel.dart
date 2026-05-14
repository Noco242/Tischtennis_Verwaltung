// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

enum ZusageStatus { offen, zugesagt, abgesagt }

ZusageStatus zusageStatusFromString(String? s) {
  switch (s) {
    case 'zugesagt':
      return ZusageStatus.zugesagt;
    case 'abgesagt':
      return ZusageStatus.abgesagt;
    default:
      return ZusageStatus.offen;
  }
}

String zusageStatusToApi(ZusageStatus s) => s.name;

class Zusage {
  final int id;
  final int spielId;
  final int spielerId;
  final ZusageStatus status;
  final String? kommentar;

  Zusage({
    required this.id,
    required this.spielId,
    required this.spielerId,
    required this.status,
    this.kommentar,
  });

  factory Zusage.fromJson(Map<String, dynamic> j) => Zusage(
        id: j['id'] as int,
        spielId: j['spiel_id'] as int,
        spielerId: j['spieler_id'] as int,
        status: zusageStatusFromString(j['status'] as String?),
        kommentar: j['kommentar'] as String?,
      );
}

class AufstellungEintrag {
  final int position;
  final int spielerId;
  final bool istErsatz;

  AufstellungEintrag({
    required this.position,
    required this.spielerId,
    this.istErsatz = false,
  });

  factory AufstellungEintrag.fromJson(Map<String, dynamic> j) => AufstellungEintrag(
        position: j['position'] as int,
        spielerId: j['spieler_id'] as int,
        istErsatz: j['ist_ersatz'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'spieler_id': spielerId,
        'ist_ersatz': istErsatz,
      };
}

class Spiel {
  final int id;
  final int mannschaftId;
  final String gegner;
  final bool istHeimspiel;
  final DateTime termin;
  final String? ort;
  final String? treffpunktOrt;
  final DateTime? treffpunktZeit;
  final String? notiz;
  final bool aufstellungFreigegeben;
  final List<AufstellungEintrag> aufstellung;
  final List<Zusage> zusagen;

  Spiel({
    required this.id,
    required this.mannschaftId,
    required this.gegner,
    required this.istHeimspiel,
    required this.termin,
    this.ort,
    this.treffpunktOrt,
    this.treffpunktZeit,
    this.notiz,
    this.aufstellungFreigegeben = false,
    this.aufstellung = const [],
    this.zusagen = const [],
  });

  factory Spiel.fromJson(Map<String, dynamic> j) => Spiel(
        id: j['id'] as int,
        mannschaftId: j['mannschaft_id'] as int,
        gegner: j['gegner'] as String,
        istHeimspiel: j['ist_heimspiel'] as bool,
        termin: DateTime.parse(j['termin'] as String),
        ort: j['ort'] as String?,
        treffpunktOrt: j['treffpunkt_ort'] as String?,
        treffpunktZeit: j['treffpunkt_zeit'] != null
            ? DateTime.parse(j['treffpunkt_zeit'] as String)
            : null,
        notiz: j['notiz'] as String?,
        aufstellungFreigegeben: j['aufstellung_freigegeben'] as bool? ?? false,
        aufstellung: (j['aufstellung'] as List? ?? [])
            .map((e) => AufstellungEintrag.fromJson(e as Map<String, dynamic>))
            .toList(),
        zusagen: (j['zusagen'] as List? ?? [])
            .map((e) => Zusage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
