"""SQLite log of pickup requests for the owners page.

The file path comes from SQLITE_PATH (default /data/pickups.db). Docker mounts
a volume there so the list survives restarts. WAL mode lets the two gunicorn
workers share the file.
"""

from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone
from typing import Any


def db_path() -> str:
    return os.environ.get("SQLITE_PATH", "/data/pickups.db").strip() or "/data/pickups.db"


def connect() -> sqlite3.Connection:
    path = db_path()
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    conn = sqlite3.connect(path, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS pickup_requests (
            reference_id TEXT PRIMARY KEY,
            order_id TEXT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL,
            address_line2 TEXT NOT NULL DEFAULT '',
            pickup_when TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL,
            is_test INTEGER NOT NULL DEFAULT 0,
            done INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS pickup_requests_created ON pickup_requests (created_at)"
    )
    conn.commit()
    return conn


def save_pickup(
    *,
    reference_id: str,
    order_id: str | None,
    name: str,
    phone: str,
    email: str,
    address: str,
    address_line2: str,
    pickup_when: str,
    notes: str,
    source: str,
    is_test: bool,
    created_at: str | None = None,
) -> None:
    if source not in {"web", "app"}:
        source = "web"
    created = created_at or datetime.now(timezone.utc).isoformat()
    conn = connect()
    try:
        conn.execute(
            """
            INSERT OR IGNORE INTO pickup_requests (
                reference_id, order_id, name, phone, email, address, address_line2,
                pickup_when, notes, source, is_test, done, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
            """,
            (
                reference_id,
                order_id,
                name,
                phone,
                email,
                address,
                address_line2,
                pickup_when,
                notes,
                source,
                1 if is_test else 0,
                created,
            ),
        )
        conn.commit()
    finally:
        conn.close()


def list_pickups(*, include_tests: bool, limit: int = 400) -> list[dict[str, Any]]:
    query = "SELECT * FROM pickup_requests"
    if not include_tests:
        query += " WHERE is_test = 0"
    query += " ORDER BY created_at DESC LIMIT ?"
    conn = connect()
    try:
        rows = conn.execute(query, (limit,)).fetchall()
        return [_row_to_dict(row) for row in rows]
    finally:
        conn.close()


def set_done(reference_id: str, done: bool) -> bool:
    conn = connect()
    try:
        cursor = conn.execute(
            "UPDATE pickup_requests SET done = ? WHERE reference_id = ?",
            (1 if done else 0, reference_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    finally:
        conn.close()


def _row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "reference_id": row["reference_id"],
        "order_id": row["order_id"],
        "name": row["name"],
        "phone": row["phone"],
        "email": row["email"],
        "address": row["address"],
        "address_line2": row["address_line2"],
        "when": row["pickup_when"],
        "notes": row["notes"],
        "source": row["source"],
        "is_test": bool(row["is_test"]),
        "done": bool(row["done"]),
        "created_at": row["created_at"],
    }
