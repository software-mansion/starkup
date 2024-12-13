#!/bin/sh
# shellcheck shell=dash

set -eu

ASDF_REPO="https://github.com/asdf-vm/asdf"
SCARB_UNINSTALL_DOCS="https://docs.swmansion.com/scarb/download#uninstall"
STARKNET_FOUNDRY_UNINSTALL_DOCS="PENDING"

ANSI_ESCAPES_ARE_VALID=false

main() {
    determine_ansi_escapes_valid

    assert_dependencies

    assert_not_installed "scarb" $SCARB_UNINSTALL_DOCS
	install_asdf_plugin "scarb"
    install_latest_version "scarb"
    set_global_version "scarb"

    assert_not_installed "starknet-foundry" $STARKNET_FOUNDRY_UNINSTALL_DOCS
    install_asdf_plugin "starknet-foundry"
    # Reinstall to ensure latest version of USC is installed
    uninstall_latest_version "starknet-foundry"
    install_latest_version "starknet-foundry"
    set_global_version "starknet-foundry"

	say "Installation complete"
}

determine_ansi_escapes_valid() {
    if [ -t 2 ]; then
        if [ "${TERM+set}" = 'set' ]; then
            case "$TERM" in
                xterm*|rxvt*|urxvt*|linux*|vt*)
                    ANSI_ESCAPES_ARE_VALID=true
                ;;
            esac
        fi
    fi
}

assert_dependencies() {
    need_cmd curl
    need_cmd git

    if ! check_cmd asdf; then
        err "asdf-vm is required. Please refer to ${ASDF_REPO} for installation instructions."
    fi
}

assert_not_installed() {
    local tool="$1"
    local uninstall_docs_url="$2"

    if ! asdf which "$tool" > /dev/null 2>&1; then
        if check_cmd "$tool"; then
            err "$tool is already installed outside of asdf. Please uninstall it and re-run this script again. For more information, refer to the documentation: $uninstall_docs_url"
        fi
    fi
}

install_asdf_plugin() {
    local plugin="$1"
    if asdf plugin list | grep -q "$plugin"; then
        ensure asdf plugin update "$plugin"
    else
        ensure asdf plugin add "$plugin"
    fi
}

install_latest_version() {
    local tool="$1"
    ensure asdf install "$tool" latest
}

uninstall_latest_version() {
    local tool="$1"
    local latest_version=$(asdf latest "$tool")
    ensure asdf uninstall "$tool" "$latest_version"
}

set_global_version() {
    local tool="$1"
    ensure asdf global "$tool" latest
}

say() {
    if $ANSI_ESCAPES_ARE_VALID; then
        printf "\033[1mstarknetup:\033[0m %s\n" "$1"
    else
        printf "starknetup: %s\n" "$1"
    fi
}

err() {
    if $ANSI_ESCAPES_ARE_VALID; then
        printf "\033[1mstarknetup: error:\033[0m %s\n" "$1" >&2
    else
        printf "starknetup: error: %s\n" "$1" >&2
    fi
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

ensure() {
    if ! "$@"; then err "command failed: $*"; fi
}

main "$@" || exit 1
