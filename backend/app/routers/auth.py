from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Spieler, Rolle, SpielerStatus
from ..schemas import LoginRequest, RegisterRequest, TokenResponse, SpielerRead
from ..security import create_access_token, hash_password, verify_password
from ..deps import get_current_spieler


router = APIRouter(prefix="/auth", tags=["auth"])


def _login_response(spieler: Spieler) -> TokenResponse:
    token = create_access_token(subject=str(spieler.id), extra={"rolle": spieler.rolle.value})
    return TokenResponse(access_token=token, spieler_id=spieler.id, rolle=spieler.rolle)


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    spieler = db.query(Spieler).filter(Spieler.email == req.email).first()
    if not spieler or not verify_password(req.passwort, spieler.passwort_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Falsche Anmeldedaten")
    if spieler.status == SpielerStatus.GESPERRT:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Account gesperrt")
    return _login_response(spieler)


@router.post("/login-form", response_model=TokenResponse, include_in_schema=False)
def login_form(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)) -> TokenResponse:
    spieler = db.query(Spieler).filter(Spieler.email == form.username).first()
    if not spieler or not verify_password(form.password, spieler.passwort_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Falsche Anmeldedaten")
    return _login_response(spieler)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    exists = db.query(Spieler).filter(Spieler.email == req.email).first()
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "E-Mail bereits registriert")
    spieler = Spieler(
        vorname=req.vorname,
        nachname=req.nachname,
        email=req.email,
        passwort_hash=hash_password(req.passwort),
        rolle=Rolle.SPIELER,
    )
    db.add(spieler)
    db.commit()
    db.refresh(spieler)
    return _login_response(spieler)


@router.get("/me", response_model=SpielerRead)
def me(current: Spieler = Depends(get_current_spieler)) -> Spieler:
    return current
