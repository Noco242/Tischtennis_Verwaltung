import enum


class Rolle(str, enum.Enum):
    ADMIN = "admin"
    MANNSCHAFTSFUEHRER = "mannschaftsfuehrer"
    SPIELER = "spieler"


class SpielerStatus(str, enum.Enum):
    AKTIV = "aktiv"
    PASSIV = "passiv"
    GESPERRT = "gesperrt"


class ZusageStatus(str, enum.Enum):
    OFFEN = "offen"
    ZUGESAGT = "zugesagt"
    ABGESAGT = "abgesagt"
