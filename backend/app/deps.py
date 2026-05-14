# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .database import get_db
from .models import Spieler, Rolle
from .security import decode_token


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login-form", auto_error=False)


def get_current_spieler(
    token: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> Spieler:
    if not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Nicht authentifiziert")
    try:
        payload = decode_token(token)
        spieler_id = int(payload.get("sub"))
    except (ValueError, TypeError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Ungueltiges Token")
    spieler = db.get(Spieler, spieler_id)
    if not spieler:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Spieler nicht gefunden")
    return spieler


def require_rolle(*rollen: Rolle):
    def _check(current: Spieler = Depends(get_current_spieler)) -> Spieler:
        if current.rolle not in rollen:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Nicht berechtigt")
        return current

    return _check


def require_admin(current: Spieler = Depends(get_current_spieler)) -> Spieler:
    if current.rolle != Rolle.ADMIN:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin-Recht erforderlich")
    return current
