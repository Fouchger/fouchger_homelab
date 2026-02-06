# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/__main__.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Entry point: python -m fhl_menu
# =============================================================================

from fhl_menu.bootstrap import run


def main() -> int:
    """Console-script entry point."""
    return int(run())


if __name__ == "__main__":
    raise SystemExit(run())
