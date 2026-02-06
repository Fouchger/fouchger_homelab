"""direct_runner.py
Notes:
- Direct execution on the control plane using subprocess.
- Uses argv list (no shell=True) for safer execution.
- Writes stdout/stderr to runs/<run_id>/ for auditability.
"""
from __future__ import annotations

import os
import subprocess
from datetime import datetime
from pathlib import Path

from .runner_base import Runner
from .jobs import Job, JobResult


class DirectRunner(Runner):
    def __init__(self, runs_dir: Path) -> None:
        self._runs_dir = runs_dir

    def describe(self) -> str:
        return "Direct execution on control plane"

    def execute(self, job: Job) -> JobResult:
        run_dir = self._runs_dir / job.run_id
        run_dir.mkdir(parents=True, exist_ok=True)

        stdout_path = run_dir / "stdout.log"
        stderr_path = run_dir / "stderr.log"

        started_at = datetime.utcnow()

        with stdout_path.open("wb") as out, stderr_path.open("wb") as err:
            proc = subprocess.Popen(
                job.argv,
                cwd=str(job.cwd),
                env={**os.environ, **job.env},
                stdout=out,
                stderr=err,
            )

            exit_code = proc.wait()

        finished_at = datetime.utcnow()
        return JobResult(
            run_id=job.run_id,
            exit_code=exit_code,
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            started_at=started_at,
            finished_at=finished_at,
        )
