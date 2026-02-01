#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/dialog_api.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   High-level dialog API with sensible defaults per widget and per-call
#   overrides via temporary DIALOGRC files.
#
# Notes:
#   - Designed to be used across Proxmox LXC/VM contexts with best-effort TTY
#     detection (see env.sh).
#   - Size defaults can be overridden with environment variables, for example:
#       DIALOG_DEFAULT_MENU_H=20
#       DIALOG_DEFAULT_MENU_W=90
#       DIALOG_DEFAULT_MENU_LISTH=15
#       DIALOG_DEFAULT_MENU_INTENT=warn
# -----------------------------------------------------------------------------

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dialogrc.sh"

# Defaults per widget (you can override via env vars; see dlg_default_get below)
declare -A DLG_DEF_H=(
  [menu]=15 [inputmenu]=15 [checklist]=18 [radiolist]=18 [buildlist]=18 [treeview]=18
  [msgbox]=10 [yesno]=10 [infobox]=6
  [inputbox]=10 [passwordbox]=10
  [form]=20 [mixedform]=20 [passwordform]=20
  [gauge]=8 [mixedgauge]=12 [pause]=8
  [textbox]=20 [tailbox]=20 [tailboxbg]=20 [progressbox]=20 [programbox]=20 [prgbox]=20
  [fselect]=20 [dselect]=20 [editbox]=20
  [calendar]=0 [timebox]=0 [rangebox]=10
)

declare -A DLG_DEF_W=(
  [menu]=70 [inputmenu]=70 [checklist]=75 [radiolist]=75 [buildlist]=75 [treeview]=75
  [msgbox]=70 [yesno]=70 [infobox]=60
  [inputbox]=70 [passwordbox]=70
  [form]=80 [mixedform]=80 [passwordform]=80
  [gauge]=70 [mixedgauge]=70 [pause]=70
  [textbox]=80 [tailbox]=80 [tailboxbg]=80 [progressbox]=80 [programbox]=80 [prgbox]=80
  [fselect]=80 [dselect]=80 [editbox]=80
  [calendar]=0 [timebox]=0 [rangebox]=70
)

declare -A DLG_DEF_LISTH=(
  [menu]=10 [inputmenu]=10 [checklist]=12 [radiolist]=12 [buildlist]=12 [treeview]=12
)

declare -A DLG_DEF_FORMH=(
  [form]=12 [mixedform]=12 [passwordform]=12
)

dlg_default_get() {
  # Allows env override:
  #   DIALOG_DEFAULT_MENU_H=20
  #   DIALOG_DEFAULT_MENU_W=80
  #   DIALOG_DEFAULT_MENU_LISTH=15
  #   DIALOG_DEFAULT_MENU_INTENT=warn
  local widget="$1" key="$2" fallback="$3"
  local var="DIALOG_DEFAULT_${widget^^}_${key}"
  local val="${!var:-}"
  if [[ -n "$val" ]]; then
    echo "$val"
  else
    echo "$fallback"
  fi
}

dlg_color_name() {
  # Accept curses names, 0-7, or Catppuccin-ish names.
  local c="${1:-}"
  c="${c,,}"
  case "$c" in
    0|black) echo "BLACK" ;;
    1|red|maroon) echo "RED" ;;
    2|green) echo "GREEN" ;;
    3|yellow|peach) echo "YELLOW" ;;
    4|blue|sapphire) echo "BLUE" ;;
    5|magenta|pink|mauve|lavender|flamingo) echo "MAGENTA" ;;
    6|cyan|teal|sky) echo "CYAN" ;;
    7|white|rosewater) echo "WHITE" ;;
    *) echo "${c^^}" ;;
  esac
}

dlg_attr() {
  # (fg,bg,highlight)
  local fg="$1" bg="$2" hl="${3:-OFF}"
  echo "(${fg^^},${bg^^},${hl^^})"
}

dlg__build_rc_for_call() {
  local widget="$1" intent="$2" explicit_rc="$3"
  shift 3
  local -a rc_sets=("$@")

  local base_rc
  if [[ -n "$explicit_rc" ]]; then
    base_rc="$explicit_rc"
  else
    # intent can be empty; default per widget or global
    local i="$intent"
    if [[ -z "$i" ]]; then
      i="$(dlg_default_get "$widget" "INTENT" "${DIALOG_DEFAULT_INTENT:-normal}")"
    fi
    base_rc="$(dialogrc_ensure_variant "$i")"
  fi

  if (( ${#rc_sets[@]} == 0 )); then
    echo "$base_rc"
    return 0
  fi

  dialogrc_make_temp_override "$base_rc" "${rc_sets[@]}"
}

dlg__dialog_common_opts() {
  local widget="$1" title="$2" backtitle="$3"

  # --colors allows \Z sequences; dialog is still constrained to curses colours.
  local -a opts=(--clear --colors)

  # Make --colors work inside programbox/tailbox/textbox contents as well.
  case "$widget" in
    programbox|progressbox|textbox|tailbox|tailboxbg) opts+=(--color-mode 2) ;;
  esac

  [[ -n "$backtitle" ]] && opts+=(--backtitle "$backtitle")
  [[ -n "$title" ]] && opts+=(--title "$title")

  printf '%s\0' "${opts[@]}"
}

dlg__run() {
  # Non-output widgets. Important: keep stdin intact for gauge/programbox/progressbox piping.
  local rc="$1"; shift
  DIALOGRC="$rc" dialog "$@" >"$TTY_DEV" 2>&1
}

dlg__out() {
  # Output widgets: capture stderr output while dialog draws to tty.
  local rc="$1"; shift
  local out
  out=$(DIALOGRC="$rc" dialog "$@" 2>&1 >"$TTY_DEV") || return $?
  printf '%s' "$out"
}

dlg() {
  # Generic wrapper for all supported dialog widgets.
  #
  # Usage:
  #   choice=$(dlg menu --title "Main" --intent info -- -- "Pick" "1" "One" "2" "Two")
  #
  # Common overrides:
  #   --title STR
  #   --backtitle STR
  #   --intent normal|info|success|warn|error   (or a curses color)
  #   --accent COLOR                            (alias: sets selection/title/border)
  #   --height N  --width N
  #   --list-height N   (for menu/checklist/radiolist/treeview/buildlist/inputmenu)
  #   --form-height N   (for form/mixedform/passwordform)
  #
  # Title/text color overrides (via temp DIALOGRC):
  #   --title-fg COLOR --title-bg COLOR --title-hl ON|OFF
  #   --text-fg COLOR  --text-bg COLOR  --text-hl ON|OFF
  #
  # Arbitrary dialogrc override:
  #   --rc-set key=value   (value can be "(FG,BG,ON)" or "dialog_color" etc)
  #
  local widget="$1"; shift

  local title="" backtitle=""
  local intent="" accent=""
  local height="" width="" list_h="" form_h=""
  local explicit_rc=""
  local title_fg="" title_bg="" title_hl=""
  local text_fg="" text_bg="" text_hl=""
  local -a rc_sets=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --backtitle) backtitle="$2"; shift 2 ;;
      --intent|--theme) intent="$2"; shift 2 ;;
      --accent) accent="$2"; shift 2 ;;

      --height|--h) height="$2"; shift 2 ;;
      --width|--w) width="$2"; shift 2 ;;
      --list-height|--list-h|--menu-height) list_h="$2"; shift 2 ;;
      --form-height|--form-h) form_h="$2"; shift 2 ;;

      --rc) explicit_rc="$2"; shift 2 ;;
      --rc-set) rc_sets+=("$2"); shift 2 ;;

      --title-fg) title_fg="$2"; shift 2 ;;
      --title-bg) title_bg="$2"; shift 2 ;;
      --title-hl) title_hl="$2"; shift 2 ;;

      --text-fg) text_fg="$2"; shift 2 ;;
      --text-bg) text_bg="$2"; shift 2 ;;
      --text-hl) text_hl="$2"; shift 2 ;;

      --) shift; break ;;
      *) break ;;
    esac
  done

  # Defaults
  [[ -z "$height" ]] && height="$(dlg_default_get "$widget" "H" "${DLG_DEF_H[$widget]:-0}")"
  [[ -z "$width"  ]] && width="$(dlg_default_get "$widget" "W" "${DLG_DEF_W[$widget]:-0}")"
  [[ -z "$list_h" ]] && list_h="$(dlg_default_get "$widget" "LISTH" "${DLG_DEF_LISTH[$widget]:-0}")"
  [[ -z "$form_h" ]] && form_h="$(dlg_default_get "$widget" "FORMH" "${DLG_DEF_FORMH[$widget]:-0}")"

  # accent is a shortcut: treat it as intent color
  [[ -n "$accent" ]] && intent="$accent"

  # Build rc overrides (title/text colors)
  if [[ -n "$title_fg" || -n "$title_bg" || -n "$title_hl" ]]; then
    local tf tb th
    tf="$(dlg_color_name "${title_fg:-MAGENTA}")"
    tb="$(dlg_color_name "${title_bg:-BLACK}")"
    th="${title_hl:-ON}"
    rc_sets+=("title_color=$(dlg_attr "$tf" "$tb" "$th")")
  fi

  if [[ -n "$text_fg" || -n "$text_bg" || -n "$text_hl" ]]; then
    local xf xb xh
    xf="$(dlg_color_name "${text_fg:-WHITE}")"
    xb="$(dlg_color_name "${text_bg:-BLACK}")"
    xh="${text_hl:-OFF}"
    local dc
    dc="$(dlg_attr "$xf" "$xb" "$xh")"
    rc_sets+=("dialog_color=$dc")
    # keep related surfaces consistent when overriding dialog_color
    rc_sets+=("menubox_color=dialog_color" "item_color=dialog_color" "check_color=dialog_color")
  fi

  # Pick rc for call
  local rc tmp_rc=""
  rc="$(dlg__build_rc_for_call "$widget" "$intent" "$explicit_rc" "${rc_sets[@]}")"
  tmp_rc="$rc"

  # Common dialog options
  local -a common
  IFS=$'\0' read -r -d '' -a common < <(dlg__dialog_common_opts "$widget" "$title" "$backtitle")

  # Widget dispatcher
  local -a args=("$@")
  local out
  case "$widget" in
    # ----- lists/menus -----
    menu|inputmenu)
      # args: text [ tag item ]...
      out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width" "$list_h" "${args[@]:1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;
    checklist|radiolist|buildlist)
      # args: text [ tag item status ]...
      out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width" "$list_h" "${args[@]:1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;
    treeview)
      # args: text [ tag item status depth ]...
      out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width" "$list_h" "${args[@]:1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;

    # ----- message boxes -----
    msgbox|yesno|infobox)
      dlg__run "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width"
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;

    # ----- input boxes -----
    inputbox|passwordbox)
      # args: text [init]
      if [[ ${#args[@]} -ge 2 ]]; then
        out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width" "${args[1]}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      else
        out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      fi
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;

    # ----- forms -----
    form|mixedform|passwordform)
      out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width" "$form_h" "${args[@]:1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;

    # ----- file widgets -----
    dselect|fselect|editbox)
      # args: filepath
      out="$(dlg__out "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;
    textbox|tailbox|tailboxbg)
      # args: file
      dlg__run "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width"
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;

    # ----- progress -----
    gauge)
      # args: text [percent] ; reads stdin for updates, so do not capture
      if [[ ${#args[@]} -ge 2 ]]; then
        dlg__run "$rc" "${common[@]}" --gauge "${args[0]}" "$height" "$width" "${args[1]}"
      else
        dlg__run "$rc" "${common[@]}" --gauge "${args[0]}" "$height" "$width" 0
      fi
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;
    mixedgauge)
      # args: text percent [tag item]...
      dlg__run "$rc" "${common[@]}" --mixedgauge "${args[0]}" "$height" "$width" "${args[1]:-0}" "${args[@]:2}"
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;
    pause)
      # args: text seconds
      dlg__run "$rc" "${common[@]}" --pause "${args[0]}" "$height" "$width" "${args[1]:-3}"
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;
    prgbox)
      # args: [text] command
      # if only one arg, it's the command; if >=2, treat as (text, command)
      if [[ ${#args[@]} -ge 2 ]]; then
        dlg__run "$rc" "${common[@]}" --prgbox "${args[0]}" "${args[1]}" "$height" "$width"
      else
        dlg__run "$rc" "${common[@]}" --prgbox "${args[0]}" "$height" "$width"
      fi
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;
    programbox|progressbox)
      # args: [text]
      if [[ ${#args[@]} -ge 1 ]]; then
        dlg__run "$rc" "${common[@]}" "--$widget" "${args[0]}" "$height" "$width"
      else
        dlg__run "$rc" "${common[@]}" "--$widget" "$height" "$width"
      fi
      local st=$?
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      return $st
      ;;

    # ----- date/time/range -----
    calendar)
      # args: text [day month year]
      out="$(dlg__out "$rc" "${common[@]}" --calendar "${args[0]}" "$height" "$width" "${args[1]:--1}" "${args[2]:--1}" "${args[3]:--1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;
    timebox)
      # args: text [hour minute second]
      out="$(dlg__out "$rc" "${common[@]}" --timebox "${args[0]}" "$height" "$width" "${args[1]:--1}" "${args[2]:--1}" "${args[3]:--1}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;
    rangebox)
      # args: text min max default
      out="$(dlg__out "$rc" "${common[@]}" --rangebox "${args[0]}" "$height" "$width" "${args[1]}" "${args[2]}" "${args[3]}")" || { [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"; return $?; }
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      printf '%s' "$out"
      ;;

    *)
      [[ -f "$tmp_rc" && "$tmp_rc" == *dlgrc.* ]] && rm -f "$tmp_rc"
      echo "Unsupported widget: $widget" >&2
      return 2
      ;;
  esac
}
