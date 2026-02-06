"""
gitops_runner.py
Notes:
- Placeholder. A GitOps runner would:
  1) Write desired state/config into a repo workspace
  2) Commit + push + open PR or push to a branch
  3) CI runner applies and reports back
- Keeping the interface now avoids future refactors.
"""
from __future__ import annotations

from .runner_base import Runner
from .jobs import Job


class GitOpsRunner(Runner):
    def __init__(self, repo_path: str) -> None:
        self._repo_path = repo_path

    def describe(self) -> str:
        return f"GitOps execution via repo: {self._repo_path}"

    def execute(self, job: Job) -> int:
        raise NotImplementedError("GitOps runner not implemented yet")
