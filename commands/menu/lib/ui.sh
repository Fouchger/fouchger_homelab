#!/usr/bin/env bash

# -----------------------------
# Capability checks
# -----------------------------
supports_color() {
    [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]
}

supports_truecolor() {
    # Common env hints for 24-bit support
    [[ "${COLORTERM:-}" =~ (truecolor|24bit) ]] || [[ "${TERM:-}" =~ (truecolor|24bit) ]]
}

# -----------------------------
# ANSI helpers (truecolor + 256 fallback)
# -----------------------------
ansi_fg_rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
ansi_bg_rgb() { printf '\033[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
ansi_fg_256() { printf '\033[38;5;%dm' "$1"; }
ansi_bg_256() { printf '\033[48;5;%dm' "$1"; }

hex_to_rgb() {
    local hex="${1#\#}"
    # Expect RRGGBB
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf '%d %d %d' "$r" "$g" "$b"
}

# Convert RGB to nearest xterm-256 color index (approx)
rgb_to_ansi256() {
    local r="$1" g="$2" b="$3"

    # 6x6x6 cube levels used by xterm-256
    local -a lvl=(0 95 135 175 215 255)

    # Map 0..255 -> 0..5 (simple rounding)
    local r6=$(( (r + 25) / 51 )); ((r6>5)) && r6=5
    local g6=$(( (g + 25) / 51 )); ((g6>5)) && g6=5
    local b6=$(( (b + 25) / 51 )); ((b6>5)) && b6=5

    local cr="${lvl[$r6]}" cg="${lvl[$g6]}" cb="${lvl[$b6]}"
    local cube_index=$((16 + 36*r6 + 6*g6 + b6))

    # grayscale ramp 232..255, values 8..238 step 10
    local avg=$(((r + g + b) / 3))
    local gi=$(( (avg - 8 + 5) / 10 ))
    ((gi<0)) && gi=0
    ((gi>23)) && gi=23
    local gv=$((8 + 10*gi))
    local gray_index=$((232 + gi))

    # Choose nearest by squared distance
    local dcube=$(( (r-cr)*(r-cr) + (g-cg)*(g-cg) + (b-cb)*(b-cb) ))
    local dgray=$(( (r-gv)*(r-gv) + (g-gv)*(g-gv) + (b-gv)*(b-gv) ))

    if (( dgray < dcube )); then
        printf '%d' "$gray_index"
    else
        printf '%d' "$cube_index"
    fi
}

ansi_fg_hex() {
    local hex="$1"
    local r g b idx
    read -r r g b <<<"$(hex_to_rgb "$hex")"

    if supports_truecolor; then
        ansi_fg_rgb "$r" "$g" "$b"
    else
        idx="$(rgb_to_ansi256 "$r" "$g" "$b")"
        ansi_fg_256 "$idx"
    fi
}

ansi_bg_hex() {
    local hex="$1"
    local r g b idx
    read -r r g b <<<"$(hex_to_rgb "$hex")"

    if supports_truecolor; then
        ansi_bg_rgb "$r" "$g" "$b"
    else
        idx="$(rgb_to_ansi256 "$r" "$g" "$b")"
        ansi_bg_256 "$idx"
    fi
}

# -----------------------------
# Catppuccin palette loader
# -----------------------------
catppuccin_load_palette() {
    local flavour="${1:-MOCHA}"
    flavour="${flavour^^}"

    # accept FRAPPÉ as well
    [[ "$flavour" == "FRAPPÉ" ]] && flavour="FRAPPE"

    case "$flavour" in
        LATTE)
            CTP_ROSEWATER="#dc8a78"; CTP_FLAMINGO="#dd7878"; CTP_PINK="#ea76cb"; CTP_MAUVE="#8839ef"
            CTP_RED="#d20f39"; CTP_MAROON="#e64553"; CTP_PEACH="#fe640b"; CTP_YELLOW="#df8e1d"
            CTP_GREEN="#40a02b"; CTP_TEAL="#179299"; CTP_SKY="#04a5e5"; CTP_SAPPHIRE="#209fb5"
            CTP_BLUE="#1e66f5"; CTP_LAVENDER="#7287fd"
            CTP_TEXT="#4c4f69"; CTP_SUBTEXT1="#5c5f77"; CTP_SUBTEXT0="#6c6f85"
            CTP_OVERLAY2="#7c7f93"; CTP_OVERLAY1="#8c8fa1"; CTP_OVERLAY0="#9ca0b0"
            CTP_SURFACE2="#acb0be"; CTP_SURFACE1="#bcc0cc"; CTP_SURFACE0="#ccd0da"
            CTP_BASE="#eff1f5"; CTP_MANTLE="#e6e9ef"; CTP_CRUST="#dce0e8"
            ;;
        FRAPPE)
            CTP_ROSEWATER="#f2d5cf"; CTP_FLAMINGO="#eebebe"; CTP_PINK="#f4b8e4"; CTP_MAUVE="#ca9ee6"
            CTP_RED="#e78284"; CTP_MAROON="#ea999c"; CTP_PEACH="#ef9f76"; CTP_YELLOW="#e5c890"
            CTP_GREEN="#a6d189"; CTP_TEAL="#81c8be"; CTP_SKY="#99d1db"; CTP_SAPPHIRE="#85c1dc"
            CTP_BLUE="#8caaee"; CTP_LAVENDER="#babbf1"
            CTP_TEXT="#c6d0f5"; CTP_SUBTEXT1="#b5bfe2"; CTP_SUBTEXT0="#a5adce"
            CTP_OVERLAY2="#949cbb"; CTP_OVERLAY1="#838ba7"; CTP_OVERLAY0="#737994"
            CTP_SURFACE2="#626880"; CTP_SURFACE1="#51576d"; CTP_SURFACE0="#414559"
            CTP_BASE="#303446"; CTP_MANTLE="#292c3c"; CTP_CRUST="#232634"
            ;;
        MACCHIATO)
            CTP_ROSEWATER="#f4dbd6"; CTP_FLAMINGO="#f0c6c6"; CTP_PINK="#f5bde6"; CTP_MAUVE="#c6a0f6"
            CTP_RED="#ed8796"; CTP_MAROON="#ee99a0"; CTP_PEACH="#f5a97f"; CTP_YELLOW="#eed49f"
            CTP_GREEN="#a6da95"; CTP_TEAL="#8bd5ca"; CTP_SKY="#91d7e3"; CTP_SAPPHIRE="#7dc4e4"
            CTP_BLUE="#8aadf4"; CTP_LAVENDER="#b7bdf8"
            CTP_TEXT="#cad3f5"; CTP_SUBTEXT1="#b8c0e0"; CTP_SUBTEXT0="#a5adcb"
            CTP_OVERLAY2="#939ab7"; CTP_OVERLAY1="#8087a2"; CTP_OVERLAY0="#6e738d"
            CTP_SURFACE2="#5b6078"; CTP_SURFACE1="#494d64"; CTP_SURFACE0="#363a4f"
            CTP_BASE="#24273a"; CTP_MANTLE="#1e2030"; CTP_CRUST="#181926"
            ;;
        MOCHA|*)
            flavour="MOCHA"
            CTP_ROSEWATER="#f5e0dc"; CTP_FLAMINGO="#f2cdcd"; CTP_PINK="#f5c2e7"; CTP_MAUVE="#cba6f7"
            CTP_RED="#f38ba8"; CTP_MAROON="#eba0ac"; CTP_PEACH="#fab387"; CTP_YELLOW="#f9e2af"
            CTP_GREEN="#a6e3a1"; CTP_TEAL="#94e2d5"; CTP_SKY="#89dceb"; CTP_SAPPHIRE="#74c7ec"
            CTP_BLUE="#89b4fa"; CTP_LAVENDER="#b4befe"
            CTP_TEXT="#cdd6f4"; CTP_SUBTEXT1="#bac2de"; CTP_SUBTEXT0="#a6adc8"
            CTP_OVERLAY2="#9399b2"; CTP_OVERLAY1="#7f849c"; CTP_OVERLAY0="#6c7086"
            CTP_SURFACE2="#585b70"; CTP_SURFACE1="#45475a"; CTP_SURFACE0="#313244"
            CTP_BASE="#1e1e2e"; CTP_MANTLE="#181825"; CTP_CRUST="#11111b"
            ;;
    esac

    export CATPPUCCIN_FLAVOUR="$flavour"
}

# -----------------------------
# Style constants
# -----------------------------
if supports_color; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    UNDERLINE=$'\033[4m'
else
    RESET=""; BOLD=""; DIM=""; UNDERLINE=""
fi

# -----------------------------
# Emojis (fallback-safe)
# -----------------------------
supports_emoji() {
    [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]
}

if supports_emoji; then
    EMO_SYSTEM="🖥️"
    EMO_NET="🌐"
    EMO_EXIT="🚪"
else
    EMO_SYSTEM="[SYS]"
    EMO_NET="[NET]"
    EMO_EXIT="[EXIT]"
fi

# -----------------------------
# Apply Catppuccin flavour + semantic roles
# -----------------------------
CATPPUCCIN_FLAVOUR="${CATPPUCCIN_FLAVOUR:-MOCHA}"
catppuccin_load_palette "$CATPPUCCIN_FLAVOUR"

if supports_color; then
    # semantic foreground roles
    C_TEXT="$(ansi_fg_hex "$CTP_TEXT")"
    C_SUBTEXT="$(ansi_fg_hex "$CTP_SUBTEXT1")"
    C_MUTED="$(ansi_fg_hex "$CTP_OVERLAY1")"

    C_ACCENT="$(ansi_fg_hex "$CTP_MAUVE")"
    C_INFO="$(ansi_fg_hex "$CTP_BLUE")"
    C_SUCCESS="$(ansi_fg_hex "$CTP_GREEN")"
    C_WARN="$(ansi_fg_hex "$CTP_YELLOW")"
    C_ERROR="$(ansi_fg_hex "$CTP_RED")"

    # handy UI roles
    C_TITLE="${BOLD}$(ansi_fg_hex "$CTP_LAVENDER")"
    C_KEY="$(ansi_fg_hex "$CTP_SAPPHIRE")"
    C_PROMPT="${BOLD}$(ansi_fg_hex "$CTP_PEACH")"

    # optional backgrounds if you want them later
    BG_BASE="$(ansi_bg_hex "$CTP_BASE")"
    BG_MANTLE="$(ansi_bg_hex "$CTP_MANTLE")"
    BG_CRUST="$(ansi_bg_hex "$CTP_CRUST")"

    # backwards compatibility (existing code may use these)
    RED="$C_ERROR"
    GREEN="$C_SUCCESS"
    BLUE="$C_INFO"
    YELLOW="$C_WARN"
else
    C_TEXT=""; C_SUBTEXT=""; C_MUTED=""
    C_ACCENT=""; C_INFO=""; C_SUCCESS=""; C_WARN=""; C_ERROR=""
    C_TITLE=""; C_KEY=""; C_PROMPT=""
    BG_BASE=""; BG_MANTLE=""; BG_CRUST=""
    RED=""; GREEN=""; BLUE=""; YELLOW=""
fi
