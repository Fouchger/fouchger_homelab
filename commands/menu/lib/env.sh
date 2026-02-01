#!/usr/bin/env bash

detect_environment() {
    UI_MODE="noninteractive"

    if [[ -c /dev/tty ]] && [[ "${TERM:-dumb}" != "dumb" ]] && command -v dialog >/dev/null 2>&1; then
        UI_MODE="dialog"
        TTY_DEV="/dev/tty"
    elif [[ -t 0 ]]; then
        UI_MODE="text"
    fi

    export UI_MODE
}
