#!/bin/sh
# shellcheck shell=dash

set -eu

ASDF_REPO="https://github.com/asdf-vm/asdf"
SCARB_UNINSTALL_DOCS="https://docs.swmansion.com/scarb/download#uninstall"
STARKNET_FOUNDRY_UNINSTALL_DOCS="PENDING"
SCRIPT_VERSION="0.1.0"

LOCAL_BIN="${HOME}/.local/bin"
LOCAL_BIN_ESCAPED="\$HOME/.local/bin"

usage() {
    cat <<EOF
The installer for Starknet tools. Installs the latest versions of Scarb, Starknet Foundry and Universal Sierra Compiler using asdf.

Usage: $0 [OPTIONS]

Options:
  -h, --help      Print help
  -V, --version   Print script version

EOF
}

main() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                printf "starknetup %s\n" "$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                err "invalid option '$arg'. For more information, try '--help'."
                exit 1
                ;;
        esac
    done

    assert_dependencies
    assert_not_installed "scarb" $SCARB_UNINSTALL_DOCS
    install_latest_asdf_plugin "scarb"
    install_latest_version "scarb"
    set_global_version "scarb"

    assert_not_installed "starknet-foundry" $STARKNET_FOUNDRY_UNINSTALL_DOCS
    install_latest_asdf_plugin "starknet-foundry"
    uninstall_latest_version "starknet-foundry"
    install_latest_version "starknet-foundry"
    set_global_version "starknet-foundry"

    say "Installation complete"
}

assert_dependencies() {
    need_cmd curl
    need_cmd git
    if ! check_cmd asdf; then
        install_asdf_interactively
    fi
}

assert_not_installed() {
    local tool="$1"
    local uninstall_docs_url="$2"

    if ! asdf which "$tool" > /dev/null 2>&1; then
        if check_cmd "$tool"; then
            err "$tool is already installed outside of asdf. Please uninstall it and re-run this script. Refer to $uninstall_docs_url"
        fi
    fi
}

install_latest_asdf_plugin() {
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
    local latest_version
    latest_version=$(asdf latest "$tool")
    
    if asdf list "$tool" "^${latest_version}$" >/dev/null 2>&1; then
        ensure asdf uninstall "$tool" "$latest_version"
    fi
}

set_global_version() {
    local tool="$1"
    ensure asdf global "$tool" latest
}

say() {
    printf "starknetup: %s\n" "$1"
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

install_asdf_interactively() {
    local _profile
    local _pref_shell
    local _asdf_dir="$HOME/.asdf"

    case ${SHELL:-""} in
        */zsh)
            _profile=$HOME/.zshrc
            _pref_shell=zsh
            ;;
        */fish)
            _profile=$HOME/.config/fish/config.fish
            _pref_shell=fish
            ;;
        */elvish)
            _profile=$HOME/.config/elvish/rc.elv
            _pref_shell=elvish
            ;;
        */pwsh)
            _profile=$HOME/.config/powershell/profile.ps1
            _pref_shell=pwsh
            ;;
        */nu)
            _profile=$HOME/.config/nushell/config.nu
            _pref_shell=nu
            ;;
        */ash)
            _profile=$HOME/.profile
            _pref_shell=ash
            ;;
        */bash)
            if [ "$(uname)" = "Darwin" ]; then
                _profile=$HOME/.bash_profile
            else
                _profile=$HOME/.bashrc
            fi
            _pref_shell=bash
            ;;
        *)
            err "could not detect shell, manually add '${LOCAL_BIN_ESCAPED}' to your PATH."
            ;;
    esac

    if [ -n "$_profile" ]; then
        if [ ! -f "$_profile" ]; then
            touch "$_profile"
        fi

        printf "asdf-vm is required. Do you want to install it now? (y/N): "
        read -r answer
        case $answer in
            [Yy]* )
                printf "Installing asdf-vm...\n"
                git clone https://github.com/asdf-vm/asdf.git "$_asdf_dir" --branch v0.14.1

                case $_pref_shell in
                    zsh|bash|ash)
                        echo >>"$_profile" && echo ". ${_asdf_dir}/asdf.sh" >>"$_profile"
                        echo >>"$_profile" && echo ". ${_asdf_dir}/completions/asdf.bash" >>"$_profile"
                        ;;
                    fish)
                        echo >>"$_profile" && echo "source ${_asdf_dir}/asdf.fish" >>"$_profile"
                        mkdir -p "$HOME/.config/fish/completions"
                        ln -s "${_asdf_dir}/completions/asdf.fish" "$HOME/.config/fish/completions"
                        ;;
                    elvish)
                        echo >>"$_profile" && echo "use asdf _asdf; var asdf~ = $_asdf:asdf~" >>"$_profile"
                        echo >>"$_profile" && echo "set edit:completion:arg-completer[asdf] = $_asdf:arg-completer~" >>"$_profile"
                        ;;
                    pwsh)
                        echo >>"$_profile" && echo ". '${_asdf_dir}/asdf.ps1'" >>"$_profile"
                        ;;
                    nu)
                        echo >>"$_profile" && echo "\$env.ASDF_DIR = '${_asdf_dir}'" >>"$_profile"
                        echo >>"$_profile" && echo "source '${_asdf_dir}/asdf.nu'" >>"$_profile"
                        ;;
                esac

                printf "asdf-vm has been installed. Please restart your shell for the changes to take effect.\n"
                exit 0
                ;;
            * )
                err "asdf-vm is required. Please install it manually and re-run this script. Refer to ${ASDF_REPO} for installation instructions."
                ;;
        esac
    else
        err "asdf-vm is required. Please install it manually and re-run this script. Refer to ${ASDF_REPO} for installation instructions."
    fi
}

main "$@" || exit 1
