#!/bin/sh
# shellcheck shell=dash

set -eu

ASDF_REPO="https://github.com/asdf-vm/asdf"
SCARB_UNINSTALL_DOCS="https://docs.swmansion.com/scarb/download#uninstall"
STARKNET_FOUNDRY_UNINSTALL_DOCS=""

main() {
    assert_dependencies
    assert_not_installed "scarb" $SCARB_UNINSTALL_DOCS
    assert_not_installed "starknet-foundry" $STARKNET_FOUNDRY_UNINSTALL_DOCS
    install_asdf_plugins "scarb" "starknet-foundry"
    install_latest_versions "scarb" "starknet-foundry"
    set_global_versions "scarb" "starknet-foundry"
    say "Starknet tools installed successfully."
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

install_asdf_plugins() {
    for plugin in "$@"; do
        if ! asdf plugin list | grep -q "$plugin"; then
            ensure asdf plugin add "$plugin"
        fi
    done
}

install_latest_versions() {
    for tool in "$@"; do
        ensure asdf install "$tool" latest
    done
}

set_global_versions() {
    for tool in "$@"; do
        ensure asdf global "$tool" latest
    done
}

say() {
    printf 'starknetup: %s\n' "$1"
}

warn() {
    say "Warning: $1" >&2
}

err() {
    say "$1" >&2
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
