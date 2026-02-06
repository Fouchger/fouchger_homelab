"""proxmox.py
Notes:
- v1 provides preflight checks only.
- Future increments will add cluster discovery, node selection, and task runs.
"""

from __future__ import annotations

from .tool_base import ToolScreen, PreflightCheck


class ProxmoxScreen(ToolScreen):
    TITLE = "Proxmox"
    CHECKS = [
        PreflightCheck("pvesh present", ["bash", "-lc", "command -v pvesh && pvesh version"]),
        PreflightCheck("qm present", ["bash", "-lc", "command -v qm && qm --version || true"]),
        PreflightCheck("pvecm (cluster) present", ["bash", "-lc", "command -v pvecm && pvecm status || true"]),
    ]
