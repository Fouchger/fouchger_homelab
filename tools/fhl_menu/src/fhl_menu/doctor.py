# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/doctor.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Diagnostics report (terminal, OS, config/log paths).
# =============================================================================

from __future__ import annotations

import platform
import sys
from dataclasses import dataclass
from pathlib import Path

from fhl_menu.util import TerminalCapabilities


@dataclass(frozen=True)
class DoctorReport:
    text: str


def build_doctor_report(
    *,
    capabilities: TerminalCapabilities,
    config_path: Path,
    log_path: Path,
) -> DoctorReport:
    lines: list[str] = []
    lines.append("Fouchger HomeLab doctor report")
    lines.append("")
    lines.append(f"Python: {sys.version.split()[0]}")
    lines.append(f"Platform: {platform.platform()}")
    lines.append("")
    lines.append("Terminal")
    lines.append(f"  is_tty: {capabilities.is_tty}")
    lines.append(f"  TERM: {capabilities.term!r}")
    lines.append(f"  is_tmux: {capabilities.is_tmux}")
    lines.append(f"  has_color_256: {capabilities.has_color_256}")
    lines.append(f"  is_dumb: {capabilities.is_dumb}")
    lines.append("")
    lines.append("Paths")
    lines.append(f"  config: {config_path}")
    lines.append(f"  logs:   {log_path}")
    lines.append("")
    lines.append("Suggestions")
    if capabilities.is_dumb or not capabilities.is_tty:
        lines.append("  - Terminal looks limited. Use CLI mode or SSH from MobaXterm.")
    if not capabilities.has_color_256:
        lines.append("  - Consider: export TERM=xterm-256color")
    if capabilities.is_tmux:
        lines.append('  - If using tmux, ensure 256 colour is enabled (e.g. default-terminal "screen-256color").')
    if (not capabilities.is_dumb) and capabilities.is_tty:
        lines.append("  - Environment looks suitable for Textual TUI.")
    lines.append("")

    return DoctorReport(text="\n".join(lines))
