"""terraform.py
Notes:
- v1 provides preflight checks only.
- Future increments will add workspace/state management and plan/apply flows.
"""

from __future__ import annotations

from .tool_base import ToolScreen, PreflightCheck


class TerraformScreen(ToolScreen):
    TITLE = "Terraform"
    CHECKS = [
        PreflightCheck("terraform present", ["bash", "-lc", "command -v terraform && terraform version"]),
    ]
