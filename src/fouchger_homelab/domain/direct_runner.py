"""
direct_runner.py
Notes:
- Direct execution on the control plane using subprocess.
- Uses argv list (no shell=True) for safer execution.
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from .runner_base import Runner
from .jobs import Job


class DirectRunner(Runner):
    def __init__(self, runs_dir: Path) -> None:
        self._runs_dir = runs_dir

    def describe(self) -> str:
        return "Direct execution on control plane"

    def execute(self, job: Job) -> int:
        run_dir = self._runs_dir / job.run_id
        run_dir.mkdir(parents=True, exist_ok=True)

        stdout_path = run_dir / "stdout.log"
        stderr_path = run_dir / "stderr.log"

        with stdout_path.open("wb") as out, stderr_path.open("wb") as err:
            proc = subprocess.Popen(
                job.argv,
                cwd=str(job.cwd),
                env={**job.env, **dict(**subprocess.os.environ)},
                stdout=out,
                stderr=err,
            )
            return proc.wait()
