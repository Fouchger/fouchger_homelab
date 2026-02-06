"""menu.py

Two-level navigation for the app.

Notes:
- Left column: main sections.
- Right column: submenu for the selected section.
- Selecting a submenu emits Menu.Selected(key=...) which the App consumes.
"""

from __future__ import annotations

from typing import Dict, List, Tuple

from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import OptionList


MAIN_MENU: List[Tuple[str, str]] = [
    ("Setup Wizard", "setup"),
    ("Proxmox", "proxmox"),
    ("Ansible", "ansible"),
    ("Terraform", "terraform"),
    ("Packer", "packer"),
    ("Development Tools", "devtools"),
    ("Run History", "history"),
    ("Settings", "settings"),
]

# Every main item has at least one submenu item.
# For now, each submenu routes to the same screen id; this makes it a true
# two-level nav while keeping behaviour simple.
SUB_MENUS: Dict[str, List[Tuple[str, str]]] = {
    "setup": [("Open", "setup")],
    "proxmox": [("Open", "proxmox")],
    "ansible": [("Open", "ansible")],
    "terraform": [("Open", "terraform")],
    "packer": [("Open", "packer")],
    "devtools": [("Open", "devtools")],
    "history": [("Open", "history")],
    "settings": [("Open", "settings")],
}


class Menu(Widget):
    """Sidebar navigation (main menu + submenu)."""

    class Selected(Message):
        """Emitted when the user selects a submenu item."""

        bubble = True

        def __init__(self, key: str) -> None:
            super().__init__()
            self.key = key

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._current_main_key: str = MAIN_MENU[0][1] if MAIN_MENU else ""
        self._submenu_keys: List[str] = []

    def compose(self):
        with Horizontal(id="menu-root"):
            yield OptionList(*(label for label, _ in MAIN_MENU), id="menu-main")
            yield OptionList(id="menu-sub")

    def on_mount(self) -> None:
        self._refresh_submenu(self._current_main_key)
        # Make sure the menu receives key events immediately.
        self.query_one("#menu-main", OptionList).focus()

    def _refresh_submenu(self, main_key: str) -> None:
        sub = self.query_one("#menu-sub", OptionList)
        items = SUB_MENUS.get(main_key) or [("Open", main_key)]
        self._submenu_keys = [k for _, k in items]
        sub.clear_options()
        for label, _key in items:
            sub.add_option(label)
        # Keep a highlight so Enter works straight away.
        if len(items) > 0:
            sub.highlighted = 0
            # Navigate immediately to the default submenu action.
            # This keeps the UI responsive when users only click/arrow through
            # the main menu.
            self.post_message(self.Selected(key=self._submenu_keys[0]))

    def _set_main_from_index(self, option_index: int) -> None:
        if option_index < 0 or option_index >= len(MAIN_MENU):
            return
        main_key = MAIN_MENU[option_index][1]
        if main_key != self._current_main_key:
            self._current_main_key = main_key
            self._refresh_submenu(main_key)

    # Main menu events
    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_list.id == "menu-main":
            self._set_main_from_index(event.option_index)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_list.id == "menu-main":
            # Enter on a main section moves focus to submenu.
            self._set_main_from_index(event.option_index)
            self.query_one("#menu-sub", OptionList).focus()
            return

        if event.option_list.id == "menu-sub":
            idx = event.option_index
            if 0 <= idx < len(self._submenu_keys):
                self.post_message(self.Selected(key=self._submenu_keys[idx]))
