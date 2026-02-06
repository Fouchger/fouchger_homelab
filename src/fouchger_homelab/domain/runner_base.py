"""runner_base.py
Notes:
- Runner interface allows us to plug in alternative execution modes later.
- For v1 we ship direct execution on the control plane.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from .jobs import Job, JobResult


class Runner(ABC):
    @abstractmethod
    def describe(self) -> str:
        raise NotImplementedError

    @abstractmethod
    def execute(self, job: Job) -> JobResult:
        """Execute a job and return a structured result."""
        raise NotImplementedError
