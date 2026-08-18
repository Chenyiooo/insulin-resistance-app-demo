from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from backend.config import settings

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect() -> sqlite3.Connection:
    db_path = settings.db_path
    if "IR_APP_DB_PATH" in os.environ:
        db_path = type(settings.db_path)(os.environ["IR_APP_DB_PATH"])
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL DEFAULT '',
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sessions (
                token_hash TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS profiles (
                user_id TEXT PRIMARY KEY,
                data_json TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS checkins (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                checkin_date TEXT NOT NULL,
                source TEXT NOT NULL DEFAULT 'manual_entry',
                provenance_json TEXT,
                data_json TEXT NOT NULL,
                model_payload_json TEXT,
                risk_result_json TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_checkins_user_date
            ON checkins(user_id, checkin_date DESC);

            CREATE TABLE IF NOT EXISTS audit_events (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                event_type TEXT NOT NULL,
                metadata_json TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE INDEX IF NOT EXISTS idx_audit_events_user_created
            ON audit_events(user_id, created_at DESC);
            """
        )
        _ensure_column(conn, "checkins", "source", "TEXT NOT NULL DEFAULT 'manual_entry'")
        _ensure_column(conn, "checkins", "provenance_json", "TEXT")
        cleanup_expired_sessions(conn)


def readiness() -> dict[str, Any]:
    try:
        with connect() as conn:
            user_count = conn.execute("SELECT COUNT(*) AS count FROM users").fetchone()["count"]
            checkin_count = conn.execute("SELECT COUNT(*) AS count FROM checkins").fetchone()["count"]
        return {
            "ok": True,
            "database": "sqlite",
            "db_path": os.environ.get("IR_APP_DB_PATH", str(settings.db_path)),
            "user_count": user_count,
            "checkin_count": checkin_count,
        }
    except sqlite3.Error as exc:
        return {"ok": False, "database": "sqlite", "error": str(exc)}


def create_user(email: str, password: str, name: str = "") -> dict[str, Any]:
    normalized_email = _normalize_email(email)
    if not EMAIL_RE.match(normalized_email):
        raise ValueError("Enter a valid email address.")
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters.")

    salt = secrets.token_hex(16)
    password_hash = _hash_password(password, salt)
    user_id = str(uuid.uuid4())
    now = utc_now()

    try:
        with connect() as conn:
            conn.execute(
                """
                INSERT INTO users (id, email, name, password_hash, salt, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (user_id, normalized_email, name.strip(), password_hash, salt, now, now),
            )
    except sqlite3.IntegrityError as exc:
        raise ValueError("An account with this email already exists.") from exc

    return get_user_by_id(user_id)


def authenticate_user(email: str, password: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE email = ?",
            (_normalize_email(email),),
        ).fetchone()
    if row is None:
        return None
    expected = _hash_password(password, row["salt"])
    if not hmac.compare_digest(expected, row["password_hash"]):
        return None
    return _user_from_row(row)


def create_session(user_id: str) -> str:
    token = secrets.token_urlsafe(32)
    token_hash = _hash_token(token)
    now_dt = datetime.now(timezone.utc)
    expires_at = (now_dt + timedelta(days=settings.session_days)).isoformat()

    with connect() as conn:
        conn.execute(
            """
            INSERT INTO sessions (token_hash, user_id, expires_at, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (token_hash, user_id, expires_at, now_dt.isoformat()),
        )
    return token


def delete_session(token: str) -> None:
    with connect() as conn:
        conn.execute("DELETE FROM sessions WHERE token_hash = ?", (_hash_token(token),))


def get_user_for_token(token: str) -> dict[str, Any] | None:
    now = utc_now()
    with connect() as conn:
        cleanup_expired_sessions(conn)
        row = conn.execute(
            """
            SELECT users.*
            FROM sessions
            JOIN users ON users.id = sessions.user_id
            WHERE sessions.token_hash = ? AND sessions.expires_at > ?
            """,
            (_hash_token(token), now),
        ).fetchone()
    if row is None:
        return None
    return _user_from_row(row)


def get_user_by_id(user_id: str) -> dict[str, Any]:
    with connect() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise ValueError("User not found.")
    return _user_from_row(row)


def save_profile(user_id: str, data: dict[str, Any]) -> dict[str, Any]:
    now = utc_now()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO profiles (user_id, data_json, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                data_json = excluded.data_json,
                updated_at = excluded.updated_at
            """,
            (user_id, json.dumps(data), now),
        )
    return {"data": data, "updated_at": now}


def get_profile(user_id: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT data_json, updated_at FROM profiles WHERE user_id = ?",
            (user_id,),
        ).fetchone()
    if row is None:
        return None
    return {"data": json.loads(row["data_json"]), "updated_at": row["updated_at"]}


def save_checkin(
    user_id: str,
    checkin_date: str,
    data: dict[str, Any],
    model_payload: dict[str, Any] | None = None,
    risk_result: dict[str, Any] | None = None,
    source: str = "manual_entry",
    provenance: dict[str, Any] | None = None,
) -> dict[str, Any]:
    now = utc_now()
    checkin_id = str(uuid.uuid4())
    normalized_source = _normalize_source(source)
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO checkins (
                id, user_id, checkin_date, source, provenance_json, data_json,
                model_payload_json, risk_result_json, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                checkin_id,
                user_id,
                checkin_date,
                normalized_source,
                json.dumps(provenance) if provenance is not None else None,
                json.dumps(data),
                json.dumps(model_payload) if model_payload is not None else None,
                json.dumps(risk_result) if risk_result is not None else None,
                now,
                now,
            ),
        )
    return {
        "id": checkin_id,
        "checkin_date": checkin_date,
        "source": normalized_source,
        "provenance": provenance,
        "data": data,
        "model_payload": model_payload,
        "risk_result": risk_result,
        "created_at": now,
        "updated_at": now,
    }


def list_checkins(user_id: str, limit: int = 30) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM checkins
            WHERE user_id = ?
            ORDER BY checkin_date DESC, created_at DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
    return [_checkin_from_row(row) for row in rows]


def latest_checkin(user_id: str) -> dict[str, Any] | None:
    rows = list_checkins(user_id, limit=1)
    return rows[0] if rows else None


def export_user_data(user_id: str) -> dict[str, Any]:
    user = get_user_by_id(user_id)
    return {
        "user": user,
        "profile": get_profile(user_id),
        "checkins": list_checkins(user_id, limit=1000),
        "audit_events": list_audit_events(user_id, limit=1000),
        "exported_at": utc_now(),
    }


def delete_user(user_id: str) -> None:
    with connect() as conn:
        conn.execute("DELETE FROM users WHERE id = ?", (user_id,))


def log_event(user_id: str | None, event_type: str, metadata: dict[str, Any] | None = None) -> None:
    metadata = _scrub_metadata(metadata or {})
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO audit_events (id, user_id, event_type, metadata_json, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                str(uuid.uuid4()),
                user_id,
                event_type,
                json.dumps(metadata) if metadata else None,
                utc_now(),
            ),
        )


def list_audit_events(user_id: str, limit: int = 100) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM audit_events
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
    return [_audit_event_from_row(row) for row in rows]


def cleanup_expired_sessions(conn: sqlite3.Connection | None = None) -> None:
    if conn is not None:
        conn.execute("DELETE FROM sessions WHERE expires_at <= ?", (utc_now(),))
        return
    with connect() as owned_conn:
        cleanup_expired_sessions(owned_conn)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _normalize_source(source: str | None) -> str:
    cleaned = (source or "manual_entry").strip().lower()
    if not cleaned:
        return "manual_entry"
    return re.sub(r"[^a-z0-9_.-]", "_", cleaned)[:80]


def _scrub_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    blocked_keys = {"password", "token", "authorization", "data", "model_payload", "risk_result"}
    return {
        str(key): value
        for key, value in metadata.items()
        if str(key).lower() not in blocked_keys
    }


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    if any(row["name"] == column for row in rows):
        return
    conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _hash_password(password: str, salt: str) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        210_000,
    )
    return digest.hex()


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _user_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "email": row["email"],
        "name": row["name"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _checkin_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "checkin_date": row["checkin_date"],
        "source": row["source"],
        "provenance": json.loads(row["provenance_json"]) if row["provenance_json"] else None,
        "data": json.loads(row["data_json"]),
        "model_payload": json.loads(row["model_payload_json"]) if row["model_payload_json"] else None,
        "risk_result": json.loads(row["risk_result_json"]) if row["risk_result_json"] else None,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _audit_event_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "event_type": row["event_type"],
        "metadata": json.loads(row["metadata_json"]) if row["metadata_json"] else {},
        "created_at": row["created_at"],
    }
