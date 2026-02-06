"""
paths.py
Notes:
- All runtime artefacts live under $HOME/app/fouchger_homelab by design.
- This keeps the control plane self-contained and easy to back up or restore.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AppPaths:
    root: Path
    config_dir: Path
    state_dir: Path
    logs_dir: Path
    runs_dir: Path

    @staticmethod
    def from_home(app_dir_name: str = "fouchger_homelab") -> "AppPaths":
        root = Path.home() / "app" / app_dir_name
        return AppPaths(
            root=root,
            config_dir=root / "config",
            state_dir=root / "state",
            logs_dir=root / "logs",
            runs_dir=root / "runs",
        )

    def ensure(self) -> None:
        for p in (self.root, self.config_dir, self.state_dir, self.logs_dir, self.runs_dir):
            p.mkdir(parents=True, exist_ok=True)
