#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/logging.sh
# Created: 2026-01-11
# Updated: 2026-01-25
# Description:
#   Two-layer logging helpers for Bash scripts.
#
#   Layer 1: Structured operator log (enabled)
#     - Consistent timestamps and levels
#     - Optional Catppuccin colours for terminal output
#     - Optional clean, line-oriented log file for operations and grepping
#
#   Layer 2: Session capture (planned)
#     - Full terminal session recording for menu/curses-hidden output
#     - Implemented separately so Layer 1 stays reliable and uncluttered
#
# Usage:
#   source "${REPO_ROOT}/lib/logging.sh"
#   logging_set_layer1_file "${LOG_DIR}/run.clean.log"
#   info "message"; warn "message"; error "message"; ok "message"
#
# Compatibility notes:
#   - logging_set_files is retained as a thin wrapper over Layer 1.
#   - logging_begin_capture/logging_end_capture are intentionally no-ops for now.
#     They are kept to avoid hard failures if older code calls them.
#
# Maintainer: Gert
# Contributors: ddployrr project contributors
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# Layer 1: Structured operator log
# =============================================================================

# -----------------------------------------------------------------------------
# Colour helpers (Catppuccin)
# -----------------------------------------------------------------------------
uc() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

FLAVOUR="${CATPPUCCIN_FLAVOUR:-LATTE}"
FLAVOUR="$(uc "$FLAVOUR")"
case "$FLAVOUR" in LATTE|FRAPPE|MACCHIATO|MOCHA) : ;; *) FLAVOUR="LATTE" ;; esac

get_rgb() {
  local key flavour
  key="$(uc "$1")"; flavour="$FLAVOUR"
  case "${flavour}:${key}" in
    LATTE:ROSEWATER) echo "220;138;120" ;;  LATTE:FLAMINGO)  echo "221;120;120" ;;
    LATTE:PINK)      echo "234;118;203" ;;  LATTE:MAUVE)     echo "136;57;239"  ;;
    LATTE:RED)       echo "210;15;57"   ;;  LATTE:MAROON)    echo "230;69;83"   ;;
    LATTE:PEACH)     echo "254;100;11"  ;;  LATTE:YELLOW)    echo "223;142;29"  ;;
    LATTE:GREEN)     echo "64;160;43"   ;;  LATTE:TEAL)      echo "23;146;153"  ;;
    LATTE:SKY)       echo "4;165;229"   ;;  LATTE:SAPPHIRE)  echo "32;159;181"  ;;
    LATTE:BLUE)      echo "30;102;245"  ;;  LATTE:LAVENDER)  echo "114;135;253" ;;
    LATTE:TEXT)      echo "76;79;105"   ;;  LATTE:SUBTEXT1)  echo "92;95;119"   ;;
    LATTE:SUBTEXT0)  echo "108;111;133" ;;  LATTE:OVERLAY2)  echo "124;127;147" ;;
    LATTE:OVERLAY1)  echo "140;143;161" ;;  LATTE:OVERLAY0)  echo "156;160;176" ;;
    LATTE:SURFACE2)  echo "172;176;190" ;;  LATTE:SURFACE1)  echo "188;192;204" ;;
    LATTE:SURFACE0)  echo "204;208;218" ;;  LATTE:BASE)      echo "239;241;245" ;;
    LATTE:MANTLE)    echo "230;233;239" ;;  LATTE:CRUST)     echo "220;224;232" ;;

    FRAPPE:ROSEWATER) echo "242;213;207" ;; FRAPPE:FLAMINGO)  echo "238;190;190" ;;
    FRAPPE:PINK)      echo "244;184;228" ;; FRAPPE:MAUVE)     echo "202;158;230" ;;
    FRAPPE:RED)       echo "231;130;132" ;; FRAPPE:MAROON)    echo "234;153;156" ;;
    FRAPPE:PEACH)     echo "239;159;118" ;; FRAPPE:YELLOW)    echo "229;200;144" ;;
    FRAPPE:GREEN)     echo "166;209;137" ;; FRAPPE:TEAL)      echo "129;200;190" ;;
    FRAPPE:SKY)       echo "153;209;219" ;; FRAPPE:SAPPHIRE)  echo "133;193;220" ;;
    FRAPPE:BLUE)      echo "140;170;238" ;; FRAPPE:LAVENDER)  echo "186;187;241" ;;
    FRAPPE:TEXT)      echo "198;208;245" ;; FRAPPE:SUBTEXT1)  echo "181;191;226" ;;
    FRAPPE:SUBTEXT0)  echo "165;173;206" ;; FRAPPE:OVERLAY2)  echo "148;156;187" ;;
    FRAPPE:OVERLAY1)  echo "131;139;167" ;; FRAPPE:OVERLAY0)  echo "115;121;148" ;;
    FRAPPE:SURFACE2)  echo "98;104;128"  ;; FRAPPE:SURFACE1)  echo "81;87;109"   ;;
    FRAPPE:SURFACE0)  echo "65;69;89"    ;; FRAPPE:BASE)      echo "48;52;70"    ;;
    FRAPPE:MANTLE)    echo "41;44;60"    ;; FRAPPE:CRUST)     echo "35;38;52"    ;;

    MACCHIATO:ROSEWATER) echo "244;219;214" ;; MACCHIATO:FLAMINGO)  echo "240;198;198" ;;
    MACCHIATO:PINK)      echo "245;189;230" ;; MACCHIATO:MAUVE)     echo "198;160;246" ;;
    MACCHIATO:RED)       echo "237;135;150" ;; MACCHIATO:MAROON)    echo "238;153;160" ;;
    MACCHIATO:PEACH)     echo "245;169;127" ;; MACCHIATO:YELLOW)    echo "238;212;159" ;;
    MACCHIATO:GREEN)     echo "166;218;149" ;; MACCHIATO:TEAL)      echo "139;213;202" ;;
    MACCHIATO:SKY)       echo "145;215;227" ;; MACCHIATO:SAPPHIRE)  echo "125;196;228" ;;
    MACCHIATO:BLUE)      echo "138;173;244" ;; MACCHIATO:LAVENDER)  echo "183;189;248" ;;
    MACCHIATO:TEXT)      echo "202;211;245" ;; MACCHIATO:SUBTEXT1)  echo "184;192;224" ;;
    MACCHIATO:SUBTEXT0)  echo "165;173;203" ;; MACCHIATO:OVERLAY2)  echo "147;154;183" ;;
    MACCHIATO:OVERLAY1)  echo "128;135;162" ;; MACCHIATO:OVERLAY0)  echo "110;115;141" ;;
    MACCHIATO:SURFACE2)  echo "91;96;120"   ;; MACCHIATO:SURFACE1)  echo "73;77;100"   ;;
    MACCHIATO:SURFACE0)  echo "54;58;79"    ;; MACCHIATO:BASE)      echo "36;39;58"    ;;
    MACCHIATO:MANTLE)    echo "30;32;48"    ;; MACCHIATO:CRUST)     echo "24;25;38"    ;;

    MOCHA:ROSEWATER) echo "245;224;220" ;; MOCHA:FLAMINGO)  echo "242;205;205" ;;
    MOCHA:PINK)      echo "245;194;231" ;; MOCHA:MAUVE)     echo "203;166;247" ;;
    MOCHA:RED)       echo "243;139;168" ;; MOCHA:MAROON)    echo "235;160;172" ;;
    MOCHA:PEACH)     echo "250;179;135" ;; MOCHA:YELLOW)    echo "249;226;175" ;;
    MOCHA:GREEN)     echo "166;227;161" ;; MOCHA:TEAL)      echo "148;226;213" ;;
    MOCHA:SKY)       echo "137;220;235" ;; MOCHA:SAPPHIRE)  echo "116;199;236" ;;
    MOCHA:BLUE)      echo "137;180;250" ;; MOCHA:LAVENDER)  echo "180;190;254" ;;
    MOCHA:TEXT)      echo "205;214;244" ;; MOCHA:SUBTEXT1)  echo "186;194;222" ;;
    MOCHA:SUBTEXT0)  echo "166;173;200" ;; MOCHA:OVERLAY2)  echo "147;153;178" ;;
    MOCHA:OVERLAY1)  echo "127;132;156" ;; MOCHA:OVERLAY0)  echo "108;112;134" ;;
    MOCHA:SURFACE2)  echo "88;91;112"   ;; MOCHA:SURFACE1)  echo "69;71;90"    ;;
    MOCHA:SURFACE0)  echo "49;50;68"    ;; MOCHA:BASE)      echo "30;30;46"    ;;
    MOCHA:MANTLE)    echo "24;24;37"    ;; MOCHA:CRUST)     echo "17;17;27"    ;;

    *) echo "255;255;255" ;;
  esac
}

_supports_colour() {
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]] && return 0
  command -v tput >/dev/null 2>&1 || return 1
  local colours
  colours="$(tput colors 2>/dev/null || echo 0)"
  [[ "$colours" -ge 16 ]]
}

if _supports_colour; then
  declare -g RESET
  RESET=$'\033[0m'
  fg() { printf "\033[38;2;%sm" "$(get_rgb "$1")"; }
else
  RESET=""
  fg() { :; }
fi

# -----------------------------------------------------------------------------
# Layer 1 file target
# -----------------------------------------------------------------------------
LOG_FILE_LAYER1=""

logging_set_layer1_file() {
  # $1 = path to Layer 1 log file (clean, line-oriented)
  LOG_FILE_LAYER1="${1:-}"
}

logging_rotate_file() {
  # Rotate a log file into a backup directory, keeping a fixed number of backups.
  #
  # Arguments:
  #   $1 = log file path
  #   $2 = backup directory (e.g. "$(dirname "$1")/backup")
  #   $3 = number of backups to keep (default 5)
  #
  # Behaviour:
  #   - If the log file does not exist or is empty, no rotation occurs.
  #   - Moves the existing file to the backup directory with an ISO timestamp.
  #   - Retains only the newest N rotated files.
  local log_file="${1:-}"
  local backup_dir="${2:-}"
  local keep="${3:-5}"

  [[ -n "$log_file" && -n "$backup_dir" ]] || return 0
  [[ -f "$log_file" ]] || return 0
  [[ -s "$log_file" ]] || return 0

  mkdir -p "$backup_dir" >/dev/null 2>&1 || true

  local base ts rotated
  base="$(basename "$log_file")"
  ts="$(date -Is | tr ':' '-')"
  rotated="${backup_dir}/${base}.${ts}.bak"

  mv -f -- "$log_file" "$rotated" 2>/dev/null || return 0
  : >"$log_file" 2>/dev/null || true

  # Prune old backups (newest first, keep N)
  local n=0
  local f
  while IFS= read -r f; do
    n=$((n + 1))
    if [[ "$n" -gt "$keep" ]]; then
      rm -f -- "$f" >/dev/null 2>&1 || true
    fi
  done < <(ls -1t "${backup_dir}/${base}."*.bak 2>/dev/null || true)
}

logging__layer1_write_file() {
  local line="$1"
  [[ -n "$LOG_FILE_LAYER1" ]] || return 0
  mkdir -p "$(dirname "$LOG_FILE_LAYER1")" >/dev/null 2>&1 || true
  printf '%s\n' "$line" >>"$LOG_FILE_LAYER1" 2>/dev/null || true
}

logging__layer1_emit() {
  local colour="$1" label="$2"; shift 2
  local ts msg
  ts="$(date -Is)"
  msg="${ts} [${label}] $*"

  logging__layer1_write_file "$msg"

  if [[ -n "${NO_COLOR:-}" ]]; then
    printf '[%s] %s\n' "$label" "$*"
  else
    printf "%b[%s]%b %b%s%b\n" "$(fg "$colour")" "$label" "$RESET" "$(fg "$colour")" "$*" "$RESET"
  fi
}

info()  { logging__layer1_emit BLUE  'ℹ️ INFO'  "$*"; }
warn()  { logging__layer1_emit PEACH '⚠️ WARN'  "$*"; }
error() { logging__layer1_emit RED   '✖ ERROR' "$*"; }
ok()    { logging__layer1_emit GREEN '✔ OK'    "$*"; }

# -----------------------------------------------------------------------------
# Post-processing helper (use after capture)
# -----------------------------------------------------------------------------
logging_strip_ansi_stream() {
  # Notes:
  #   - Conservative stripping of common ANSI escapes and control characters.
  #   - Use for post-processing captured logs, not for live menu capture.
  sed -r \
    -e 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g' \
    -e 's/\x1B\][0-9;]*[^\a]*(\x07|\x1B\\)//g' \
    -e 's/\r//g' \
    -e 's/[\x00-\x08\x0B\x0C\x0E-\x1F]//g'
}

# =============================================================================
# Compatibility shims (temporary)
# =============================================================================

logging_set_files() {
  # Backwards compatible wrapper.
  # Previous behaviour supported clean + raw logs; for Layer 1 we use a single
  # line-oriented file.
  logging_set_layer1_file "${1:-}"
}

logging_begin_capture() {
  # Layer 2 will replace this approach. Keeping as a no-op prevents older code
  # from failing hard.
  :
}

logging_end_capture() {
  # No-op; see logging_begin_capture.
  :
}
