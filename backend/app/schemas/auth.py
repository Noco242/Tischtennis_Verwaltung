# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

from pydantic import BaseModel, EmailStr

from ..models.enums import Rolle


class LoginRequest(BaseModel):
    email: EmailStr
    passwort: str


class RegisterRequest(BaseModel):
    vorname: str
    nachname: str
    email: EmailStr
    passwort: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    spieler_id: int
    rolle: Rolle
