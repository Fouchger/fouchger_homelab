"""config.py
Notes:
- Simple YAML config with sensible defaults.
- Supports single Proxmox node and clusters (multiple endpoints/nodes).
- For v1 we run directly on the control plane; the config model keeps room
  to add alternative execution strategies later.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import yaml


@dataclass
class ProxmoxConfig:
    endpoints: list[str] = field(default_factory=list)  # e.g. ["https://pve1:8006", "https://pve2:8006"]
    verify_tls: bool = True


@dataclass
class RunnerConfig:
    mode: str = "direct"  # currently only "direct" is supported


@dataclass
class AppConfig:
    proxmox: ProxmoxConfig = field(default_factory=ProxmoxConfig)
    runner: RunnerConfig = field(default_factory=RunnerConfig)

    @staticmethod
    def load(path: Path) -> "AppConfig":
        if not path.exists():
            cfg = AppConfig()
            AppConfig.save(cfg, path)
            return cfg

        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        prox = raw.get("proxmox", {}) or {}
        run = raw.get("runner", {}) or {}

        return AppConfig(
            proxmox=ProxmoxConfig(
                endpoints=list(prox.get("endpoints", []) or []),
                verify_tls=bool(prox.get("verify_tls", True)),
            ),
            runner=RunnerConfig(
                mode=str(run.get("mode", "direct")),
            ),
        )

    @staticmethod
    def save(cfg: "AppConfig", path: Path) -> None:
        payload = {
            "proxmox": {"endpoints": cfg.proxmox.endpoints, "verify_tls": cfg.proxmox.verify_tls},
            "runner": {"mode": cfg.runner.mode},
        }
        path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")
