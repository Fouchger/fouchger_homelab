#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/logger.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Minimal logger helper for the menu runtime.
# Notes:
#   - Keep this dependency-free. Any richer logging should live elsewhere.
# -----------------------------------------------------------------------------

log() {
  printf '[menu] %s\n' "$*" >&2
}
