"""ansible.py
Notes:
- v1 provides preflight checks only.
- Future increments will add inventory selection and playbook execution.
"""

from __future__ import annotations

from .tool_base import ToolScreen, PreflightCheck


class AnsibleScreen(ToolScreen):
    TITLE = "Ansible"
    CHECKS = [
        PreflightCheck("ansible-playbook present", ["bash", "-lc", "command -v ansible-playbook && ansible-playbook --version"]),
        PreflightCheck("ansible-galaxy present", ["bash", "-lc", "command -v ansible-galaxy && ansible-galaxy --version"]),
    ]
