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

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        key = MENU[event.option_index][1]
        self.post_message(self.Selected(key=key))
