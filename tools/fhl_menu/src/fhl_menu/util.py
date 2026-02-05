# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/util.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Terminal capability detection and small helpers.
# =============================================================================

from __future__ import annotations

import os
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class TerminalCapabilities:
    is_tty: bool
    term: str
    is_tmux: bool
    has_color_256: bool
    is_dumb: bool


def detect_terminal_capabilities() -> TerminalCapabilities:
    is_tty = sys.stdin.isatty() and sys.stdout.isatty()
    term = os.environ.get("TERM", "").strip()
    is_tmux = "TMUX" in os.environ
    colorterm = os.environ.get("COLORTERM", "").lower().strip()
    has_color_256 = ("256color" in term) or ("truecolor" in colorterm) or ("24bit" in colorterm)
    is_dumb = (term == "") or (term.lower() == "dumb")

    return TerminalCapabilities(
        is_tty=is_tty,
        term=term,
        is_tmux=is_tmux,
        has_color_256=has_color_256,
        is_dumb=is_dumb,
    )
