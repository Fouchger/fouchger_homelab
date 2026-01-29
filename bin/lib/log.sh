#!/usr/bin/env bash
# ==============================================================================
# fouchger_homelab/bin/lib/log.sh
#
# Purpose
#   Project-wide logging helpers for Bash scripts.
#
# Key features
#   - Colour + emojis (auto-disabled when not supported or when NO_COLOR is set)
#   - Consistent log levels with switchable verbosity (TRACE..FATAL)
#   - Works cleanly with dialog-based menus (optional FIFO + tailbox integration)
#   - Command runner that shows the true command output (stdout/stderr) as if
#     executed directly in a terminal, while still tagging start/end lines
#   - Optional file logging (LOG_FILE) with plain text (no ANSI codes)
#
# Usage
#   source "$REPO_ROOT/bin/lib/log.sh"
#   log_set_level INFO
#   log_info "Hello"
#   run_cmd "apt-get update"
#
# Environment
#   LOG_LEVEL          One of: TRACE DEBUG INFO WARN ERROR FATAL (default: INFO)
#   LOG_FILE           If set, append logs + command output to file (no colours)
#   LOG_NO_COLOR       If "1", disable colour output
#   NO_COLOR           If set (any value), disable colour output (standard)
#   LOG_TS             If "0", disable timestamps (default: 1)
#   LOG_DIALOG_FIFO    If set to a FIFO path, logs also go to FIFO (for dialog)
#   LOG_DIALOG_ACTIVE  If "1", we're in a dialog UI context (optional hint)
#
# Dialog integration (recommended pattern)
#   log_dialog_start "Installer Logs"
#   ...run things...
#   log_dialog_stop
#
# Notes
#   - If you run dialog in the foreground, printing to the terminal will
#     interfere with the UI. The FIFO + tailboxbg approach avoids that.
#   - run_cmd streams live output; it does not hide or buffer output.
# ==============================================================================

# Guard against double-sourcing
if [[ -n "${__FOUCHGER_LOG_SH_SOURCED:-}" ]]; then
  return 0
fi
readonly __FOUCHGER_LOG_SH_SOURCED=1

# -----------------------------
# Defaults
# -----------------------------
: "${LOG_LEVEL:=INFO}"
: "${LOG_TS:=1}"

# -----------------------------
# Level mapping
# -----------------------------
__log_level_to_num() {
  case "${1^^}" in
    TRACE) echo 10 ;;
    DEBUG) echo 20 ;;
    INFO)  echo 30 ;;
    WARN|WARNING)  echo 40 ;;
    ERROR) echo 50 ;;
    FATAL) echo 60 ;;
    NONE|OFF|QUIET) echo 99 ;;
    *) echo 30 ;; # default INFO
  esac
}

__LOG_LEVEL_NUM="$(__log_level_to_num "$LOG_LEVEL")"

log_set_level() {
  local lvl="${1:-INFO}"
  LOG_LEVEL="${lvl^^}"
  __LOG_LEVEL_NUM="$(__log_level_to_num "$LOG_LEVEL")"
}

log_get_level() {
  echo "$LOG_LEVEL"
}

# -----------------------------
# Colour + emoji support
# -----------------------------
__log_is_tty() { [[ -t 1 ]]; }

__log_colour_enabled() {
  # Respect NO_COLOR standard and project switches
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ "${LOG_NO_COLOR:-0}" == "1" ]] && return 1
  __log_is_tty || return 1
  command -v tput >/dev/null 2>&1 || return 1
  local colours
  colours="$(tput colors 2>/dev/null || echo 0)"
  [[ "$colours" -ge 8 ]]
}

if __log_colour_enabled; then
  __C_RESET="$(tput sgr0)"
  __C_DIM="$(tput dim)"
  __C_BOLD="$(tput bold)"
  __C_RED="$(tput setaf 1)"
  __C_GREEN="$(tput setaf 2)"
  __C_YELLOW="$(tput setaf 3)"
  __C_BLUE="$(tput setaf 4)"
  __C_MAGENTA="$(tput setaf 5)"
  __C_CYAN="$(tput setaf 6)"
  __C_WHITE="$(tput setaf 7)"
else
  __C_RESET="" __C_DIM="" __C_BOLD=""
  __C_RED="" __C_GREEN="" __C_YELLOW="" __C_BLUE="" __C_MAGENTA="" __C_CYAN="" __C_WHITE=""
fi

# Emojis can be disabled if desired, but default on
: "${LOG_NO_EMOJI:=0}"
__emoji() { [[ "${LOG_NO_EMOJI}" == "1" ]] && echo "" || echo "$1"; }

# -----------------------------
# Time + formatting helpers
# -----------------------------
__log_ts() {
  [[ "${LOG_TS}" == "0" ]] && return 0
  # ISO-ish, readable in NZ too
  date "+%Y-%m-%d %H:%M:%S"
}

__log_should_print() {
  local want_num="$1"
  [[ "$__LOG_LEVEL_NUM" -le "$want_num" ]]
}

__log_write_plain() {
  # Write a plain line (no ANSI) to LOG_FILE if set
  local line="$1"
  [[ -z "${LOG_FILE:-}" ]] && return 0
  # Ensure directory exists
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  printf "%s\n" "$line" >>"$LOG_FILE"
}

__log_write_fifo() {
  # If configured, mirror logs to dialog FIFO (tailboxbg)
  local line="$1"
  [[ -z "${LOG_DIALOG_FIFO:-}" ]] && return 0
  [[ -p "${LOG_DIALOG_FIFO}" ]] || return 0
  # FIFO should be plain text for dialog
  printf "%s\n" "$line" >"${LOG_DIALOG_FIFO}" 2>/dev/null || true
}

__log_emit() {
  # Args: level_num, level_tag, colour_prefix, emoji, message, stream(1|2)
  local level_num="$1"
  local tag="$2"
  local colour="$3"
  local emo="$4"
  local msg="$5"
  local stream="${6:-1}"

  __log_should_print "$level_num" || return 0

  local ts prefix line_plain line_col
  ts="$(__log_ts)"
  prefix=""
  [[ -n "$ts" ]] && prefix="${__C_DIM}${ts}${__C_RESET} "

  # Plain line (no ANSI) for file/FIFO
  line_plain="${ts:+$ts }[$tag] ${emo:+$emo }$msg"

  # Coloured line for terminal
  line_col="${prefix}${colour}[${tag}]${__C_RESET} ${emo:+$emo }$msg"

  # Terminal output
  if [[ "$stream" == "2" ]]; then
    printf "%b\n" "$line_col" >&2
  else
    printf "%b\n" "$line_col"
  fi

  # Mirrors
  __log_write_plain "$line_plain"
  __log_write_fifo "$line_plain"
}

# -----------------------------
# Public log functions
# -----------------------------
log_trace()   { __log_emit 10 "TRACE"   "${__C_MAGENTA}" "$(__emoji "🧭")" "$*" 1; }
log_debug()   { __log_emit 20 "DEBUG"   "${__C_CYAN}"    "$(__emoji "🪲")" "$*" 1; }
log_info()    { __log_emit 30 "INFO"    "${__C_BLUE}"    "$(__emoji "ℹ️")"  "$*" 1; }
log_warn()    { __log_emit 40 "WARN"    "${__C_YELLOW}"  "$(__emoji "⚠️")"  "$*" 2; }
log_error()   { __log_emit 50 "ERROR"   "${__C_RED}"     "$(__emoji "🧨")" "$*" 2; }
log_fatal()   { __log_emit 60 "FATAL"   "${__C_RED}${__C_BOLD}" "$(__emoji "💥")" "$*" 2; }
log_success() { __log_emit 30 "OK"      "${__C_GREEN}"   "$(__emoji "✅")" "$*" 1; }

# Convenience
log_hr() {
  local ch="${1:--}"
  local width="${2:-80}"
  local line=""
  line="$(printf "%*s" "$width" "" | tr " " "$ch")"
  __log_emit 30 "INFO" "${__C_DIM}" "" "$line" 1
}

# -----------------------------
# Dialog integration (optional)
# -----------------------------
# Starts a background tailbox that shows logs without breaking the dialog UI.
# Requires: dialog installed.
# Sets: LOG_DIALOG_FIFO, __LOG_DIALOG_TAIL_PID
log_dialog_start() {
  local title="${1:-Logs}"
  local height="${2:-20}"
  local width="${3:-100}"

  command -v dialog >/dev/null 2>&1 || {
    log_warn "dialog not found, continuing without dialog log viewer"
    return 0
  }

  # Create FIFO
  local fifo
  fifo="$(mktemp -u "/tmp/fouchger_log_fifo.XXXXXX")"
  mkfifo "$fifo"
  LOG_DIALOG_FIFO="$fifo"
  LOG_DIALOG_ACTIVE=1

  # Start tailbox in background
  dialog --title "$title" --tailboxbg "$fifo" "$height" "$width"
  __LOG_DIALOG_TAIL_PID="$!"

  log_debug "Dialog log viewer started (fifo=$LOG_DIALOG_FIFO pid=$__LOG_DIALOG_TAIL_PID)"
}

log_dialog_stop() {
  # Stop tailboxbg and clean up FIFO
  if [[ -n "${__LOG_DIALOG_TAIL_PID:-}" ]]; then
    kill "${__LOG_DIALOG_TAIL_PID}" 2>/dev/null || true
    unset __LOG_DIALOG_TAIL_PID
  fi

  if [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]]; then
    rm -f "${LOG_DIALOG_FIFO}" 2>/dev/null || true
  fi

  unset LOG_DIALOG_FIFO
  unset LOG_DIALOG_ACTIVE
  log_debug "Dialog log viewer stopped"
}

# -----------------------------
# Command execution helpers
# -----------------------------
# Runs a command and streams stdout/stderr live.
# - Adds start/end markers via logger
# - Mirrors raw output to LOG_FILE and/or LOG_DIALOG_FIFO (plain text)
# - Preserves the command's exit code
run_cmd() {
  # Accept either a single string or multiple args.
  # Examples:
  #   run_cmd "apt-get update"
  #   run_cmd apt-get update
  local cmd_display=""
  local -a cmd=()

  if [[ "$#" -eq 1 ]]; then
    cmd_display="$1"
    # shellcheck disable=SC2206
    cmd=( bash -lc "$1" )
  else
    cmd_display="$*"
    cmd=( "$@" )
  fi

  log_info "Running: ${cmd_display}"

  # Stream output. We:
  # - Keep terminal output unmodified (true output)
  # - Mirror to LOG_FILE (plain) and FIFO (plain) without adding prefixes
  # - Still keep our own start/end log lines
  local rc=0

  if [[ -n "${LOG_FILE:-}" || -n "${LOG_DIALOG_FIFO:-}" ]]; then
    # Use process substitution to tee into file and/or fifo while maintaining original streams.
    # stdout
    if [[ -n "${LOG_FILE:-}" ]]; then
      mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    fi

    # We do not add any formatting to command output; it is passed through as-is.
    "${cmd[@]}" \
      > >(tee \
            >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
            >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null )) \
      2> >(tee >&2 \
            >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
            >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null ))
    rc=$?
  else
    "${cmd[@]}"
    rc=$?
  fi

  if [[ "$rc" -eq 0 ]]; then
    log_success "Completed: ${cmd_display}"
  else
    log_error "Failed (exit $rc): ${cmd_display}"
  fi

  return "$rc"
}

# Runs a command but only shows output at DEBUG/TRACE levels.
# Useful for noisy commands while still capturing output to file/FIFO.
run_cmd_quiet() {
  local cmd_display="$*"
  if __log_should_print 20; then
    run_cmd "$@"
    return $?
  fi

  log_info "Running (quiet): ${cmd_display}"

  local rc=0
  if [[ "$#" -eq 1 ]]; then
    bash -lc "$1" >/dev/null 2>&1
    rc=$?
  else
    "$@" >/dev/null 2>&1
    rc=$?
  fi

  # Still write to file/FIFO if set by re-running with streaming but suppressed terminal output
  if [[ -n "${LOG_FILE:-}" || -n "${LOG_DIALOG_FIFO:-}" ]]; then
    if [[ "$#" -eq 1 ]]; then
      # Mirror to file/FIFO, not terminal
      bash -lc "$1" \
        > >(tee \
              >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
              >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null ) >/dev/null) \
        2> >(tee \
              >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
              >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null ) >/dev/null)
      rc=$?
    else
      "$@" \
        > >(tee \
              >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
              >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null ) >/dev/null) \
        2> >(tee \
              >( [[ -n "${LOG_FILE:-}" ]] && cat >>"$LOG_FILE" || cat >/dev/null ) \
              >( [[ -n "${LOG_DIALOG_FIFO:-}" && -p "${LOG_DIALOG_FIFO}" ]] && cat >"$LOG_DIALOG_FIFO" || cat >/dev/null ) >/dev/null)
      rc=$?
    fi
  fi

  if [[ "$rc" -eq 0 ]]; then
    log_success "Completed: ${cmd_display}"
  else
    log_error "Failed (exit $rc): ${cmd_display}"
  fi
  return "$rc"
}

# -----------------------------
# Fail-fast helpers
# -----------------------------
die() {
  log_fatal "$*"
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "Missing required command: $c"
  done
}

# -----------------------------
# Initial level normalisation
# -----------------------------
log_set_level "$LOG_LEVEL"
