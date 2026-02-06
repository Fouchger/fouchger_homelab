"""
menu.py
Notes:
- Implements the left-side menu using OptionList.
- Emits messages rather than directly controlling navigation, to keep it reusable.
"""
from __future__ import annotations

from dataclasses import dataclass
from textual.message import Message
from textual.widgets import OptionList


MENU = [
    ("Setup Wizard", "setup"),
    ("Proxmox", "proxmox"),
    ("Ansible", "ansible"),
    ("Terraform", "terraform"),
    ("Packer", "packer"),
    ("Development Tools", "devtools"),
    ("Run History", "history"),
    ("Settings", "settings"),
]


class Menu(OptionList):
    @dataclass
    class Selected(Message):
        key: str

    def __init__(self, **kwargs) -> None:
        super().__init__(* [label for label, _ in MENU], **kwargs)

    def _emit_selected(self, option_index: int) -> None:
        """Emit the Selected message for a given menu index.

        Notes:
        - In the TUI, users often expect navigation to happen as they move the
          highlight (arrow keys) and not only on Enter.
        - In the web UI, mouse clicks may trigger highlight changes without
          raising OptionSelected depending on Textual version.
        """

        if option_index < 0 or option_index >= len(MENU):
            return
        key = MENU[option_index][1]
        self.post_message(self.Selected(key=key))

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        self._emit_selected(event.option_index)

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        # Navigate on highlight movement as well.
        self._emit_selected(event.option_index)
