"""jobs.py
Notes:
- A single abstraction for operations triggered from the UI.
- Works for bash, ansible-playbook, terraform, packer.
- Jobs are immutable so they can be safely passed between threads.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime
import uuid


@dataclass(frozen=True)
class Job:
    name: str
    argv: list[str]
    cwd: Path
    env: dict[str, str] = field(default_factory=dict)
    run_id: str = field(default_factory=lambda: uuid.uuid4().hex)
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass(frozen=True)
class JobResult:
    """Result of a Job execution."""

    run_id: str
    exit_code: int
    stdout_path: Path
    stderr_path: Path
    started_at: datetime
    finished_at: datetime
