# Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.database import Base, get_db
from app.main import app


@pytest.fixture
def client(tmp_path):
    previous_checkin_enabled = settings.deployment_checkin_enabled
    settings.deployment_checkin_enabled = False
    db_url = f"sqlite:///{tmp_path/'test.db'}"
    engine = create_engine(db_url, connect_args={"check_same_thread": False}, future=True)
    TestSession = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    Base.metadata.create_all(bind=engine)

    def override():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override
    # Provide direct access to the test session for tests that need to twiddle data
    app.state.test_session_maker = TestSession  # type: ignore[attr-defined]
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_db, None)
        settings.deployment_checkin_enabled = previous_checkin_enabled
        Base.metadata.drop_all(bind=engine)
        engine.dispose()
