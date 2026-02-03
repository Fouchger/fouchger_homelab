#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/dialogrc.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Generates and patches DIALOGRC files per Catppuccin flavour and per-call
#   overrides.
#
# Notes:
#   - Uses `dialog --create-rc` for compatibility with the installed dialog
#     version.
#   - Colour mapping is constrained by curses; this is a best-effort Catppuccin
#     approximation rather than a perfect match.
# -----------------------------------------------------------------------------

_dialogrc_cache_dir() {
  echo "${XDG_CACHE_HOME:-/tmp}/homelab-menu/dialog"
}

_dialogrc_safe_flavour() {
  local f="${1:-MOCHA}"
  f="${f^^}"
  [[ "$f" == "FRAPPÉ" ]] && f="FRAPPE"
  case "$f" in
    LATTE|FRAPPE|MACCHIATO|MOCHA) echo "$f" ;;
    *) echo "MOCHA" ;;
  esac
}

_dialogrc_mktemp() {
  if command -v mktemp >/dev/null 2>&1; then
    mktemp "${1:-/tmp}/dlgrc.XXXXXX"
  else
    # very small fallback (should be rare)
    echo "${1:-/tmp}/dlgrc.$$.$RANDOM"
  fi
}

# Set or append "key = value" in a dialogrc file
_dialogrc_set() {
  local file="$1" key="$2" value="$3"
  local tmp="$(_dialogrc_mktemp "$(dirname "$file")")"
  awk -v k="$key" -v v="$value" '
    BEGIN{found=0}
    $0 ~ "^[[:space:]]*"k"[[:space:]]*=" {
      print k " = " v
      found=1
      next
    }
    {print}
    END{
      if(!found) print k " = " v
    }
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}

_dialogrc_color_name() {
  # Accept common curses colour names or 0-7.
  local c="${1:-}"
  c="${c,,}"
  case "$c" in
    0|black) echo "BLACK" ;;
    1|red) echo "RED" ;;
    2|green) echo "GREEN" ;;
    3|yellow) echo "YELLOW" ;;
    4|blue) echo "BLUE" ;;
    5|magenta) echo "MAGENTA" ;;
    6|cyan) echo "CYAN" ;;
    7|white) echo "WHITE" ;;
    *) echo "${c^^}" ;;
  esac
}

# Map Catppuccin flavour -> a coherent curses scheme (approximation)
_dialogrc_scheme_for_flavour() {
  local flavour="$(_dialogrc_safe_flavour "$1")"

  # Defaults (dark)
  SCREEN_BG="BLACK"; SCREEN_FG="WHITE"
  DIALOG_BG="BLACK"; DIALOG_FG="WHITE"

  # Accents (approx Catppuccin vibe in curses)
  ACCENT_FG="MAGENTA"     # mauve/lavender-ish
  BORDER_FG="BLUE"        # sapphire/blue-ish
  MUTED_FG="CYAN"         # teal-ish
  SELECT_BG="BLUE"
  SELECT_FG="WHITE"
  INPUT_BG="BLACK"

  case "$flavour" in
    LATTE)
      SCREEN_BG="WHITE"; SCREEN_FG="BLACK"
      DIALOG_BG="WHITE"; DIALOG_FG="BLACK"
      ACCENT_FG="MAGENTA"
      BORDER_FG="BLUE"
      MUTED_FG="BLUE"
      SELECT_BG="BLUE"
      SELECT_FG="WHITE"
      INPUT_BG="WHITE"
      ;;
    FRAPPE)
      # keep dark, slightly more teal vibe
      BORDER_FG="CYAN"
      MUTED_FG="CYAN"
      SELECT_BG="CYAN"
      SELECT_FG="BLACK"
      ;;
    MACCHIATO)
      BORDER_FG="BLUE"
      MUTED_FG="CYAN"
      SELECT_BG="BLUE"
      SELECT_FG="WHITE"
      ;;
    MOCHA)
      BORDER_FG="BLUE"
      MUTED_FG="CYAN"
      SELECT_BG="BLUE"
      SELECT_FG="WHITE"
      ;;
  esac

  # Global background overrides (optional).
  # These are applied after the flavour mapping, so they win.
  [[ -n "${DIALOG_SCREEN_BG:-}" ]] && SCREEN_BG="$(_dialogrc_color_name "$DIALOG_SCREEN_BG")"
  [[ -n "${DIALOG_SCREEN_FG:-}" ]] && SCREEN_FG="$(_dialogrc_color_name "$DIALOG_SCREEN_FG")"
  [[ -n "${DIALOG_DIALOG_BG:-}" ]] && DIALOG_BG="$(_dialogrc_color_name "$DIALOG_DIALOG_BG")"
  [[ -n "${DIALOG_DIALOG_FG:-}" ]] && DIALOG_FG="$(_dialogrc_color_name "$DIALOG_DIALOG_FG")"
}

# Decide readable foreground for a given background color
_dialogrc_contrast_fg() {
  local bg="${1^^}"
  case "$bg" in
    YELLOW|WHITE|CYAN) echo "BLACK" ;;
    *) echo "WHITE" ;;
  esac
}

# Apply base Catppuccin-ish theme to an rc file
_dialogrc_apply_catppuccin() {
  local flavour="$(_dialogrc_safe_flavour "$1")"
  local file="$2"

  _dialogrc_scheme_for_flavour "$flavour"

  # Enable colours; shadow is subjective. Default OFF, configurable.
  _dialogrc_set "$file" "use_colors" "ON"
  _dialogrc_set "$file" "use_shadow" "${DIALOG_USE_SHADOW:-OFF}"

  # Core surfaces
  _dialogrc_set "$file" "screen_color" "($SCREEN_FG,$SCREEN_BG,OFF)"
  _dialogrc_set "$file" "shadow_color" "(BLACK,BLACK,OFF)"
  _dialogrc_set "$file" "dialog_color" "($DIALOG_FG,$DIALOG_BG,OFF)"
  _dialogrc_set "$file" "title_color" "($ACCENT_FG,$DIALOG_BG,ON)"
  _dialogrc_set "$file" "border_color" "($BORDER_FG,$DIALOG_BG,ON)"

  # Buttons
  _dialogrc_set "$file" "button_active_color" "($SELECT_FG,$SELECT_BG,ON)"
  _dialogrc_set "$file" "button_inactive_color" "dialog_color"
  _dialogrc_set "$file" "button_key_active_color" "(YELLOW,$SELECT_BG,ON)"
  _dialogrc_set "$file" "button_key_inactive_color" "(YELLOW,$DIALOG_BG,OFF)"
  _dialogrc_set "$file" "button_label_active_color" "($SELECT_FG,$SELECT_BG,ON)"
  _dialogrc_set "$file" "button_label_inactive_color" "($DIALOG_FG,$DIALOG_BG,OFF)"

  # Inputs / searches
  _dialogrc_set "$file" "inputbox_color" "($DIALOG_FG,$INPUT_BG,OFF)"
  _dialogrc_set "$file" "inputbox_border_color" "border_color"
  _dialogrc_set "$file" "searchbox_color" "($DIALOG_FG,$INPUT_BG,OFF)"
  _dialogrc_set "$file" "searchbox_title_color" "title_color"
  _dialogrc_set "$file" "searchbox_border_color" "border_color"
  _dialogrc_set "$file" "position_indicator_color" "title_color"

  # Menus/lists
  _dialogrc_set "$file" "menubox_color" "dialog_color"
  _dialogrc_set "$file" "menubox_border_color" "border_color"
  _dialogrc_set "$file" "item_color" "dialog_color"
  _dialogrc_set "$file" "item_selected_color" "($SELECT_FG,$SELECT_BG,ON)"
  _dialogrc_set "$file" "tag_color" "($BORDER_FG,$DIALOG_BG,ON)"
  _dialogrc_set "$file" "tag_selected_color" "($SELECT_FG,$SELECT_BG,ON)"
  _dialogrc_set "$file" "tag_key_color" "(YELLOW,$DIALOG_BG,OFF)"
  _dialogrc_set "$file" "tag_key_selected_color" "(YELLOW,$SELECT_BG,ON)"

  # Checkboxes/radios
  _dialogrc_set "$file" "check_color" "dialog_color"
  _dialogrc_set "$file" "check_selected_color" "($SELECT_FG,$SELECT_BG,ON)"

  # Arrows/help
  _dialogrc_set "$file" "uarrow_color" "($MUTED_FG,$DIALOG_BG,ON)"
  _dialogrc_set "$file" "darrow_color" "uarrow_color"
  _dialogrc_set "$file" "itemhelp_color" "($MUTED_FG,$DIALOG_BG,OFF)"

  # Forms / gauge
  _dialogrc_set "$file" "form_active_text_color" "($SELECT_FG,$SELECT_BG,ON)"
  _dialogrc_set "$file" "form_text_color" "($DIALOG_FG,$DIALOG_BG,OFF)"
  _dialogrc_set "$file" "form_item_readonly_color" "($MUTED_FG,$DIALOG_BG,OFF)"
  _dialogrc_set "$file" "gauge_color" "($BORDER_FG,$DIALOG_BG,ON)"

  # Secondary borders (many builds include these)
  _dialogrc_set "$file" "border2_color" "dialog_color"
  _dialogrc_set "$file" "inputbox_border2_color" "dialog_color"
  _dialogrc_set "$file" "searchbox_border2_color" "dialog_color"
  _dialogrc_set "$file" "menubox_border2_color" "dialog_color"
}

# Apply an "intent" (accent color) to an rc file: affects title/border/selection
_dialogrc_apply_intent() {
  local flavour="$(_dialogrc_safe_flavour "$1")"
  local intent="${2:-normal}"
  local file="$3"

  _dialogrc_scheme_for_flavour "$flavour"

  local accent
  case "${intent,,}" in
    normal) return 0 ;;
    info)    accent="BLUE" ;;
    success) accent="GREEN" ;;
    warn)    accent="YELLOW" ;;
    error)   accent="RED" ;;
    *)
      # also allow passing a direct color name
      accent="${intent^^}"
      ;;
  esac

  local active_fg="$(_dialogrc_contrast_fg "$accent")"
  local active_bg="$accent"

  _dialogrc_set "$file" "title_color" "($accent,$DIALOG_BG,ON)"
  _dialogrc_set "$file" "border_color" "($accent,$DIALOG_BG,ON)"

  _dialogrc_set "$file" "menubox_border_color" "border_color"
  _dialogrc_set "$file" "inputbox_border_color" "border_color"
  _dialogrc_set "$file" "searchbox_border_color" "border_color"
  _dialogrc_set "$file" "searchbox_title_color" "title_color"
  _dialogrc_set "$file" "position_indicator_color" "title_color"
  _dialogrc_set "$file" "gauge_color" "title_color"

  _dialogrc_set "$file" "button_active_color" "($active_fg,$active_bg,ON)"
  _dialogrc_set "$file" "item_selected_color" "($active_fg,$active_bg,ON)"
  _dialogrc_set "$file" "check_selected_color" "($active_fg,$active_bg,ON)"
  _dialogrc_set "$file" "tag_selected_color" "($active_fg,$active_bg,ON)"
  _dialogrc_set "$file" "form_active_text_color" "($active_fg,$active_bg,ON)"
}

dialogrc_base_path() {
  local flavour="$(_dialogrc_safe_flavour "${CATPPUCCIN_FLAVOUR:-MOCHA}")"
  local sig="${DIALOG_USE_SHADOW:-OFF}|${DIALOG_SCREEN_BG:-}|${DIALOG_SCREEN_FG:-}|${DIALOG_DIALOG_BG:-}|${DIALOG_DIALOG_FG:-}"
  local hash
  hash="$(printf '%s' "$sig" | sha1sum 2>/dev/null | awk '{print $1}' || echo "nosha")"
  echo "$(_dialogrc_cache_dir)/dialogrc-${flavour}-${hash}.rc"
}

dialogrc_ensure_base() {
  local flavour="$(_dialogrc_safe_flavour "${CATPPUCCIN_FLAVOUR:-MOCHA}")"
  local dir="$(_dialogrc_cache_dir)"
  local base="$dir/dialogrc-${flavour}.rc"

  mkdir -p "$dir"

  if [[ -s "$base" ]]; then
    echo "$base"
    return 0
  fi

  local tmp="${base}.tmp.$$"

  # Create version-compatible rc file (then patch it)
  if ! dialog --create-rc "$tmp" >/dev/null 2>&1; then
    # Extremely rare; minimal fallback if --create-rc fails
    cat >"$tmp" <<'EOF'
use_colors = ON
use_shadow = OFF
EOF
  fi

  _dialogrc_apply_catppuccin "$flavour" "$tmp"
  mv "$tmp" "$base"
  echo "$base"
}

dialogrc_variant_path() {
  local flavour="$(_dialogrc_safe_flavour "${CATPPUCCIN_FLAVOUR:-MOCHA}")"
  local intent="${1:-normal}"
  intent="${intent,,}"
  echo "$(_dialogrc_cache_dir)/dialogrc-${flavour}-${intent}.rc"
}

dialogrc_ensure_variant() {
  local intent="${1:-normal}"
  local flavour="$(_dialogrc_safe_flavour "${CATPPUCCIN_FLAVOUR:-MOCHA}")"

  local base
  base="$(dialogrc_ensure_base)" || return 1

  if [[ "${intent,,}" == "normal" ]]; then
    echo "$base"
    return 0
  fi

  local var
  var="$(dialogrc_variant_path "$intent")"

  if [[ -s "$var" ]]; then
    echo "$var"
    return 0
  fi

  cp "$base" "$var"
  _dialogrc_apply_intent "$flavour" "$intent" "$var"
  echo "$var"
}

dialogrc_make_temp_override() {
  # Usage:
  #   dialogrc_make_temp_override <base_rc> <key=value> [key=value ...]
  local base_rc="$1"; shift
  local dir="$(_dialogrc_cache_dir)"
  mkdir -p "$dir"

  local tmp="$(_dialogrc_mktemp "$dir")"
  cp "$base_rc" "$tmp"

  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    [[ -n "$key" ]] && _dialogrc_set "$tmp" "$key" "$val"
  done

  echo "$tmp"
}

