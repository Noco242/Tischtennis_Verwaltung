"""Versand von Benachrichtigungen (E-Mail / WhatsApp).

MVP-Stub: Es wird nur protokolliert. Spaeter via SendGrid / Twilio / Mailgun.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Iterable, Literal

from ..models import Spieler

log = logging.getLogger("notifications")

Kanal = Literal["email", "whatsapp", "push"]


@dataclass
class Nachricht:
    empfaenger: Spieler
    betreff: str
    text: str
    kanaele: tuple[Kanal, ...] = ("email", "whatsapp")


def sende(nachricht: Nachricht) -> None:
    """Stub: gibt die Nachricht auf dem Logger aus."""
    for kanal in nachricht.kanaele:
        log.info(
            "[%s] -> %s <%s>: %s | %s",
            kanal.upper(),
            nachricht.empfaenger.name,
            nachricht.empfaenger.email,
            nachricht.betreff,
            nachricht.text,
        )


def sende_an_viele(nachrichten: Iterable[Nachricht]) -> None:
    for n in nachrichten:
        sende(n)
