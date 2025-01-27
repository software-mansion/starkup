#!/bin/sh

set -eu

ASDF_INSTALL_DOCS="https://asdf-vm.com/guide/getting-started.html"
SCARB_UNINSTALL_INSTRUCTIONS="For uninstallation instructions, refer to https://docs.swmansion.com/scarb/download#uninstall"
# TODO(#2): Link snfoundry uninstall docs once they are available
STARKNET_FOUNDRY_UNINSTALL_INSTRUCTIONS="Try removing snforge and sncast binaries from $HOME/.local/bin"
SCRIPT_VERSION="0.1.0"
DEFAULT_ASDF_VERSION="v0.14.1"

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
    -h | --help)
      usage
      exit 0
      ;;
    -V | --version)
      printf "starknetup %s\n" "$SCRIPT_VERSION"
      exit 0
      ;;
    *)
      err "invalid option '$arg'. For more information, try '--help'."
      ;;
    esac
  done

  assert_dependencies
  assert_not_installed "scarb" "$SCARB_UNINSTALL_INSTRUCTIONS"
  install_latest_asdf_plugin "scarb"
  install_latest_version "scarb"
  set_global_latest_version "scarb"

  assert_not_installed "starknet-foundry" "$STARKNET_FOUNDRY_UNINSTALL_INSTRUCTIONS"
  install_latest_asdf_plugin "starknet-foundry"

  # Reinstall to ensure the latest version of USC is installed
  uninstall_latest_version "starknet-foundry"
  install_latest_version "starknet-foundry"
  set_global_latest_version "starknet-foundry"

  _shell_config=""
  _completion_message=""

  case ${SHELL:-""} in
  */zsh)
    _shell_config="$HOME/.zshrc"
    _completion_message="Run 'source ${_shell_config}'"
    ;;
  */bash)
    if [ "$(uname)" = "Darwin" ]; then
      _shell_config="$HOME/.bash_profile"
    else
      _shell_config="$HOME/.bashrc"
    fi
    _completion_message="Run 'source ${_shell_config}'"
    ;;
  */sh)
    _shell_config="$HOME/.profile"
    _completion_message="Run '. ${_shell_config}'"
    ;;
  *)
    _completion_message="Source your shell configuration file"
    ;;
  esac

  say "Installation complete. ${_completion_message} or start a new terminal session to use the installed tools."
}

assert_dependencies() {
  need_cmd curl
  need_cmd git
  if ! check_cmd asdf; then
    install_asdf_interactively
  fi
}

assert_not_installed() {
  _tool="$1"
  _uninstall_instructions="$2"

  if ! asdf which "$_tool" >/dev/null 2>&1; then
    if check_cmd "$_tool"; then
      err "$_tool is already installed outside of asdf. Please uninstall it and re-run this script. $_uninstall_instructions"
    fi
  fi
}

install_latest_asdf_plugin() {
  _plugin="$1"
  if asdf plugin list | grep -q "$_plugin"; then
    ensure asdf plugin update "$_plugin"
  else
    ensure asdf plugin add "$_plugin"
  fi
}

install_latest_version() {
  _tool="$1"
  ensure asdf install "$_tool" latest
}

uninstall_latest_version() {
  _tool="$1"
  _latest_version=$(asdf latest "$_tool")

  if asdf list "$_tool" "^${_latest_version}$" >/dev/null 2>&1; then
    ensure asdf uninstall "$_tool" "$_latest_version"
  fi
}

set_global_latest_version() {
  _tool="$1"
  ensure asdf global "$_tool" latest
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
  command -v "$1" >/dev/null 2>&1
}

ensure() {
  if ! "$@"; then err "command failed: $*"; fi
}

install_asdf_interactively() {
  _profile=""
  _pref_shell=""
  _asdf_path="$HOME/.asdf"

  case ${SHELL:-""} in
  */zsh)
    _profile=$HOME/.zshrc
    _pref_shell=zsh
    ;;
  */sh)
    _profile=$HOME/.profile
    _pref_shell="sh"
    ;;
  */bash)
    if [ "$(uname)" = "Darwin" ]; then
      _profile=$HOME/.bash_profile
    else
      _profile=$HOME/.bashrc
    fi
    _pref_shell=bash
    ;;
  esac

  if [ -z "$_profile" ] || [ -z "$_pref_shell" ]; then
    err "asdf-vm is required. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi

  touch "$_profile"

  say "asdf-vm is required. Do you want to install it now? (y/N): "
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    # shellcheck disable=SC2015
    latest_asdf_version=$(curl -sS --fail https://api.github.com/repos/asdf-vm/asdf/releases/latest | awk -F'"' '/"tag_name"/ {print $4}') && [ -n "$latest_asdf_version" ] || {
      echo "Failed to fetch latest asdf version (possibly due to GitHub server rate limit or error). Using default version ${DEFAULT_ASDF_VERSION}."
      latest_asdf_version="$DEFAULT_ASDF_VERSION"
    }

    say "Installing asdf-vm ${latest_asdf_version}...\n"
    git clone https://github.com/asdf-vm/asdf.git "$_asdf_path" --branch "$latest_asdf_version"

    echo >>"$_profile" && echo ". ${_asdf_path}/asdf.sh" >>"$_profile"

    say "asdf-vm has been installed. Run 'source ${_profile}' or start a new terminal session and re-run this script."
    exit 0
  else
    err "cancelled asdf-vm installation. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi
}

main "$@" || exit 1
