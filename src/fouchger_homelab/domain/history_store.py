"""history_store.py
Notes:
- Lightweight run history stored in SQLite under state/history.db.
- We store only operationally useful metadata and pointers to artefacts.
- This is deliberately small and dependency-free (sqlite3 is in stdlib).
"""

from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from pathlib import Path

from .jobs import Job, JobResult


@dataclass(frozen=True)
class RunRecord:
    run_id: str
    created_at_utc: str
    job_name: str
    status: str
    exit_code: int
    stdout_path: str
    stderr_path: str


class HistoryStore:
    """SQLite-backed store for run records."""

    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS runs (
                    run_id TEXT PRIMARY KEY,
                    created_at_utc TEXT NOT NULL,
                    job_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    exit_code INTEGER NOT NULL,
                    stdout_path TEXT NOT NULL,
                    stderr_path TEXT NOT NULL
                )
                """
            )
            conn.commit()

    def record_started(self, job: Job) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO runs
                (run_id, created_at_utc, job_name, status, exit_code, stdout_path, stderr_path)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    job.run_id,
                    job.created_at.isoformat(),
                    job.name,
                    "running",
                    -1,
                    "",
                    "",
                ),
            )
            conn.commit()

    def record_finished(self, job: Job, result: JobResult) -> None:
        status = "success" if result.exit_code == 0 else "failed"
        with self._connect() as conn:
            conn.execute(
                """
                UPDATE runs
                SET status = ?, exit_code = ?, stdout_path = ?, stderr_path = ?
                WHERE run_id = ?
                """,
                (
                    status,
                    int(result.exit_code),
                    str(result.stdout_path),
                    str(result.stderr_path),
                    result.run_id,
                ),
            )
            conn.commit()

    def latest(self, limit: int = 200) -> list[RunRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT run_id, created_at_utc, job_name, status, exit_code, stdout_path, stderr_path
                FROM runs
                ORDER BY created_at_utc DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()

        return [
            RunRecord(
                run_id=row["run_id"],
                created_at_utc=row["created_at_utc"],
                job_name=row["job_name"],
                status=row["status"],
                exit_code=int(row["exit_code"]),
                stdout_path=row["stdout_path"],
                stderr_path=row["stderr_path"],
            )
            for row in rows
        ]
