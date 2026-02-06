"""
log_panel.py
Notes:
- RichLog supports appending renderables and strings in real time.
"""
from __future__ import annotations

from textual.widgets import RichLog


class LogPanel(RichLog):
    def write_line(self, text: str) -> None:
        self.write(text)
