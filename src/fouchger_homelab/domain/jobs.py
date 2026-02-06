"""
jobs.py
Notes:
- A single abstraction for operations triggered from the UI.
- Works for bash, ansible-playbook, terraform, packer.
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
