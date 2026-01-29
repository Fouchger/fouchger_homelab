#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/selection.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Description: Load/save current app selections to a shell state file.
#
# Notes
#   - Selections represent desired end state:
#       APP_SELECTION[<key>]="ON"  -> ensure installed
#       APP_SELECTION[<key>]="OFF" -> ensure removed
#   - State file path can be overridden with APP_SELECTION_FILE.
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

app_selection_file() { printf '%s' "${APP_SELECTION_FILE:-scripts/app_manager/state/app_selection.sh}"; }

app_selection_init_defaults_from_catalogue() {
  declare -gA APP_SELECTION=()
  local row type key _label def _packages _desc _strategy _ver
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key _label def _packages _desc _strategy _ver <<< "$row" || true
    [[ "$type" == "APP" ]] || continue
    APP_SELECTION["$key"]="$def"
  done
}

app_selection_load() {
  local file; file="$(app_selection_file)"
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC1090
    source "$file"
    declare -gA APP_SELECTION="${APP_SELECTION[@]:-}"
  else
    app_selection_init_defaults_from_catalogue
  fi
}

app_selection_save() {
  local file; file="$(app_selection_file)"
  mkdir -p "$(dirname "$file")"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '# ============================================================================='
    printf '%s\n' "# Filename: $file"
    printf '%s\n' '# Description: Generated App Manager selection state.'
    printf '%s\n' '# ============================================================================='
    printf '%s\n' 'declare -A APP_SELECTION=('
    for k in "${!APP_SELECTION[@]}"; do
      printf "  [%q]=%q\n" "$k" "${APP_SELECTION[$k]}"
    done | sort
    printf '%s\n' ')'
  } > "$file"
  chmod 0644 "$file"
}
