from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL_PATH = REPO_ROOT / "backend" / "model_artifacts" / "reduced_lightgbm_bundle.joblib"


def _bool_env(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    environment: str = os.environ.get("IR_ENV", "development")
    api_version: str = os.environ.get("IR_API_VERSION", "0.2.0")
    db_path: Path = Path(os.environ.get("IR_APP_DB_PATH", REPO_ROOT / "backend" / "app.db"))
    model_path: Path = Path(os.environ.get("IR_MODEL_PATH", DEFAULT_MODEL_PATH))
    allowed_origins: tuple[str, ...] = tuple(
        origin.strip()
        for origin in os.environ.get(
            "IR_ALLOWED_ORIGINS",
            "http://127.0.0.1:8000,http://localhost:8000",
        ).split(",")
        if origin.strip()
    )
    max_body_bytes: int = int(os.environ.get("IR_MAX_BODY_BYTES", str(5 * 1024 * 1024)))
    session_days: int = int(os.environ.get("IR_SESSION_DAYS", "30"))
    auth_window_seconds: int = int(os.environ.get("IR_AUTH_WINDOW_SECONDS", "60"))
    auth_max_requests: int = int(os.environ.get("IR_AUTH_MAX_REQUESTS", "12"))
    enable_docs: bool = _bool_env("IR_ENABLE_DOCS", default=True)

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


settings = Settings()
