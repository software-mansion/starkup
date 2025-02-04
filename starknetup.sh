#!/bin/sh

set -eu

ASDF_INSTALL_DOCS="https://asdf-vm.com/guide/getting-started.html"
SCARB_UNINSTALL_INSTRUCTIONS="For uninstallation instructions, refer to https://docs.swmansion.com/scarb/download#uninstall"
# TODO(#2): Link snfoundry uninstall docs once they are available
STARKNET_FOUNDRY_UNINSTALL_INSTRUCTIONS="Try removing snforge and sncast binaries from $HOME/.local/bin"
SCRIPT_VERSION="0.1.0"
DEFAULT_ASDF_VERSION="v0.15.0"

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
      say "starknetup $SCRIPT_VERSION"
      exit 0
      ;;
    *)
      err "invalid option '$arg'. For more information, try '--help'."
      ;;
    esac
  done

  assert_dependencies
  assert_not_installed_outside_asdf

  install_latest_asdf_plugin "scarb"
  install_latest_version "scarb"
  set_global_latest_version "scarb"

  install_universal_sierra_compiler

  install_latest_asdf_plugin "starknet-foundry"
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

assert_not_installed_outside_asdf() {
  _installed_tools=""

  for _tool in "scarb" "starknet-foundry"; do
    _uninst_instructions=""
    _tool_cmds=""

    case "$_tool" in
    "scarb")
      _uninst_instructions="$SCARB_UNINSTALL_INSTRUCTIONS"
      _tool_cmds="scarb"
      ;;
    "starknet-foundry")
      _uninst_instructions="$STARKNET_FOUNDRY_UNINSTALL_INSTRUCTIONS"
      _tool_cmds="snforge sncast"
      ;;
    esac

    if ! check_asdf_plugin_installed "$_tool"; then
      for _cmd in $_tool_cmds; do
        if check_cmd "$_cmd"; then
          _installed_tools="${_installed_tools}${_installed_tools:+\n} - $_cmd (from $_tool). $_uninst_instructions"
        fi
      done
    fi
  done

  if [ -n "$_installed_tools" ]; then
    err "The following tool(s) are already installed outside of asdf:\n$_installed_tools"
  fi
}

install_latest_asdf_plugin() {
  _plugin="$1"
  if check_asdf_plugin_installed "$_plugin"; then
    ensure asdf plugin update "$_plugin"
  else
    ensure asdf plugin add "$_plugin"
  fi
}

check_asdf_plugin_installed() {
  _plugin="$1"
  asdf plugin list | grep -xq "$_plugin"
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

get_latest_gh_version() {
  _repo="$1"
  curl -sS --fail "https://api.github.com/repos/${_repo}/releases/latest" | awk -F'"' '/"tag_name"/ {print $4}'
}

install_universal_sierra_compiler() {
  _version=""
  if check_cmd universal-sierra-compiler; then
    _version=$(universal-sierra-compiler --version 2>/dev/null | awk '{print $2}')
  fi

  _latest_version=$(get_latest_gh_version "software-mansion/universal-sierra-compiler")

  if [ -n "$_version" ] && [ "$_version" != "$_latest_version" ]; then
    curl -sSL --fail https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | ${SHELL:-sh}
  fi
}

say() {
  printf 'starknetup: %b\n' "$1"
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
  _completion_message=""
  _asdf_path="$HOME/.asdf"

  case ${SHELL:-""} in
  */zsh)
    _profile=$HOME/.zshrc
    _pref_shell=zsh
    _completion_message="Run 'source ${_profile}'"
    ;;
  */bash)
    if [ "$(uname)" = "Darwin" ]; then
      _profile=$HOME/.bash_profile
    else
      _profile=$HOME/.bashrc
    fi
    _pref_shell=bash
    _completion_message="Run 'source ${_profile}'"
    ;;
  */sh)
    _profile=$HOME/.profile
    _pref_shell="sh"
    _completion_message="Run '. ${_profile}'"
    ;;
  esac

  if [ -z "$_profile" ] || [ -z "$_pref_shell" ]; then
    err "asdf-vm is required. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi

  touch "$_profile"

  say "asdf-vm is required. Do you want to install it now? (y/N): "
  # Starknetup is going to want to ask for confirmation by
  # reading stdin. This script may be piped into `sh` though
  # and wouldn't have stdin to pass to its children. Instead we're
  # going to explicitly connect /dev/tty to the installer's stdin.
  if [ ! -t 0 ] && [ -r /dev/tty ]; then
    read -r answer </dev/tty
  else
    read -r answer
  fi
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    # TODO: https://github.com/software-mansion/scarb/issues/1938
    #   Support newer versions of asdf-vm
    _version="$DEFAULT_ASDF_VERSION"
    say "Installing asdf-vm ${_version}..."
    git clone --quiet -c advice.detachedHead=false https://github.com/asdf-vm/asdf.git "$_asdf_path" --branch "$_version"

    echo >>"$_profile" && echo ". ${_asdf_path}/asdf.sh" >>"$_profile"

    say "asdf-vm has been installed. ${_completion_message} or start a new terminal session and re-run this script."
    exit 0
  else
    err "cancelled asdf-vm installation. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi
}

main "$@" || exit 1
