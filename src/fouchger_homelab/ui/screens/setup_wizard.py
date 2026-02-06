"""
setup_wizard.py
Notes:
- This is where you'd guide first-time setup: endpoints, auth approach, repo paths, etc.
"""
from __future__ import annotations

from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import Markdown


WIZARD_MD = """\
# Setup Wizard

This will be expanded into a guided workflow:
- Configure Proxmox endpoint(s) (single node or cluster)
- Choose runner mode (direct or GitOps)
- Validate tooling presence: ansible-playbook, terraform, packer
- Create baseline inventory/state structure
"""

class SetupWizardScreen(Screen):
    def compose(self) -> ComposeResult:
        yield Markdown(WIZARD_MD)
