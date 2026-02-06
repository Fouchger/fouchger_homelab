"""
home.py
Notes:
- Lightweight landing screen.
"""
from __future__ import annotations

from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import Markdown


HOME_MD = """\
# Fouchger Homelab Control Plane

Select an option from the menu on the left.

Operational principles:
- Plan first, apply second
- Everything auditable (runs folder, logs folder)
- Modular design for adding new capabilities
"""

class HomeScreen(Screen):
    def compose(self) -> ComposeResult:
        yield Markdown(HOME_MD)
