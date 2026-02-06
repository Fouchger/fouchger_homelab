"""packer.py
Notes:
- v1 provides preflight checks only.
- Future increments will add template discovery and build pipelines.
"""

from __future__ import annotations

from .tool_base import ToolScreen, PreflightCheck


class PackerScreen(ToolScreen):
    TITLE = "Packer"
    CHECKS = [
        PreflightCheck("packer present", ["bash", "-lc", "command -v packer && packer version"]),
    ]
