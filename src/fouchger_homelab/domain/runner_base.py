"""
runner_base.py
Notes:
- Runner interface lets us switch between direct execution and GitOps later.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from .jobs import Job


class Runner(ABC):
    @abstractmethod
    def describe(self) -> str:
        raise NotImplementedError

    @abstractmethod
    def execute(self, job: Job) -> int:
        """Execute a job and return an exit code."""
        raise NotImplementedError
