# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/config.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: TOML config load/save with strict validation.
# Developer notes:
# - Schema is intentionally small and stable.
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict

from fhl_menu.constants import DEFAULT_LOG_LEVEL, SUPPORTED_LOG_LEVELS

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


def _normalise_log_level(level: str) -> str:
    lvl = (level or "").strip().upper()
    if lvl not in SUPPORTED_LOG_LEVELS:
        raise ValueError(
            f"Unsupported log level: {level!r}. Supported: {', '.join(SUPPORTED_LOG_LEVELS)}"
        )
    return lvl


@dataclass(frozen=True)
class AppConfig:
    log_level: str = DEFAULT_LOG_LEVEL

    @staticmethod
    def from_dict(data: Dict[str, Any]) -> "AppConfig":
        logging_section = data.get("logging", {}) if isinstance(data, dict) else {}
        log_level = logging_section.get("level", DEFAULT_LOG_LEVEL)
        return AppConfig(log_level=_normalise_log_level(str(log_level)))

    def to_dict(self) -> Dict[str, Any]:
        return {"logging": {"level": self.log_level}}


def load_config(config_path: Path) -> AppConfig:
    if not config_path.exists():
        return AppConfig()

    data = tomllib.loads(config_path.read_text(encoding="utf-8"))
    return AppConfig.from_dict(data)


def save_config(config_path: Path, config: AppConfig) -> None:
    config_path.parent.mkdir(parents=True, exist_ok=True)

    # Minimal TOML writer for the current schema.
    content = "\n".join(
        [
            "[logging]",
            f'level = "{config.log_level}"',
            "",
        ]
    )
    config_path.write_text(content, encoding="utf-8")
