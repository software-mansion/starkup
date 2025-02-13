#!/bin/sh

set -eu

ASDF_INSTALL_DOCS="https://asdf-vm.com/guide/getting-started.html"
SCARB_UNINSTALL_INSTRUCTIONS="For uninstallation instructions, refer to https://docs.swmansion.com/scarb/download#uninstall"
# TODO(#2): Link snfoundry uninstall docs once they are available
LOCAL_BIN="${HOME}/.local/bin"
LOCAL_BIN_ESCAPED="\${HOME}/.local/bin"
STARKNET_FOUNDRY_UNINSTALL_INSTRUCTIONS="Try removing snforge and sncast binaries from ${LOCAL_BIN}"
SCRIPT_VERSION="0.1.0"
DEFAULT_ASDF_VERSION="v0.16.2"

usage() {
  cat <<EOF
The installer for Starknet tools. Installs the latest versions of Scarb, Starknet Foundry and Universal Sierra Compiler using asdf.

Usage: $0 [OPTIONS]

Options:
  -h, --help      Print help
  -V, --version   Print script version
  -y, --yes       Disable confirmation prompt

EOF
}

main() {
  _need_interaction=true

  for arg in "$@"; do
    case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    -V | --version)
      say "starkup $SCRIPT_VERSION"
      exit 0
      ;;
    -y | --yes)
      _need_interaction=false
      ;;
    *)
      err "invalid option '$arg'. For more information, try '--help'."
      ;;
    esac
  done

  assert_dependencies "$_need_interaction"
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

  if ! check_cmd universal-sierra-compiler; then
    say "Couldn't finish universal-sierra-compiler installation, try manually adding ${LOCAL_BIN} to your PATH."
  fi

  say "Installation complete. ${_completion_message} or start a new terminal session to use the installed tools."
}

assert_dependencies() {
  _need_interaction="$1"
  need_cmd curl
  need_cmd git
  if ! check_cmd asdf; then
    install_asdf "$_need_interaction"
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
  _latest_version=$(asdf latest "$_tool")
  if check_version_installed "$_tool" "$_latest_version"; then
    say "$_tool $_latest_version is already installed"
  else
    ensure asdf install "$_tool" latest
  fi
}

check_version_installed() {
  _tool="$1"
  _version="$2"
  asdf list "$_tool" | grep -q "^[^0-9]*${_version}$"
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
  if is_asdf_legacy; then
    ensure asdf global "$_tool" latest
  else
    ensure asdf set --home "$_tool" latest
  fi
}

get_latest_gh_version() {
  _repo="$1"
  curl -sS --fail "https://api.github.com/repos/${_repo}/releases/latest" | awk -F'"' '/"tag_name"/ {print $4}'
}

install_universal_sierra_compiler() {
  _version=""
  _latest_version=""
  if check_cmd universal-sierra-compiler; then
    _version=$(universal-sierra-compiler --version 2>/dev/null | awk '{print $2}')
    _latest_version=$(get_latest_gh_version "software-mansion/universal-sierra-compiler")
  fi

  if [ -z "$_version" ] || [ "$_version" != "$_latest_version" ]; then
    curl -sSL --fail https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | ${SHELL:-sh}
  fi
}

say() {
  printf 'starkup: %b\n' "$1"
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

get_asdf_version() {
  asdf --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$'
}

# asdf versions < 0.16.0 are legacy
is_asdf_legacy() {
  _version=$(get_asdf_version)
  printf '%s\n%s' "$_version" "0.16.0" | sort -V | head -n1 | grep -xqvF "0.16.0"
}

install_asdf() {
  _need_interaction="$1"
  _answer=""
  if "$_need_interaction"; then
    say "asdf-vm is required. It can be installed via package managers, including Homebrew and Pacman.\nFor more information, visit ${ASDF_INSTALL_DOCS}.\nAlternatively, an asdf binary can be installed by starkup.\nDo you want to install it now? (y/N):"
    if [ ! -t 0 ]; then
      # Starkup is going to want to ask for confirmation by
      # reading stdin. This script may be piped into `sh` though
      # and wouldn't have stdin to pass to its children. Instead we're
      # going to explicitly connect /dev/tty to the installer's stdin.
      if [ ! -t 1 ] || [ ! -r /dev/tty ]; then
        err "Unable to run interactively."
      fi
      read -r _answer </dev/tty
    else
      read -r _answer
    fi
  else
    _answer="y"
  fi

  if [ "$_answer" = "y" ] || [ "$_answer" = "Y" ]; then
    need_cmd tar

    # shellcheck disable=SC2015
    _latest_version=$(get_latest_gh_version "asdf-vm/asdf") && [ -n "$_latest_version" ] || {
      say "Failed to fetch latest asdf version (possibly due to GitHub server rate limit or error). Using default version ${DEFAULT_ASDF_VERSION}."
      _latest_version="$DEFAULT_ASDF_VERSION"
    }

    say "Installing asdf-vm ${_latest_version}..."

    _os="$(uname -s)"
    _arch="$(uname -m)"
    case "${_os}-${_arch}" in
    "Linux-x86_64") _platform="linux-amd64" ;;
    "Linux-aarch64") _platform="linux-arm64" ;;
    "Linux-i386" | "Linux-i686") _platform="linux-386" ;;
    "Darwin-x86_64") _platform="darwin-amd64" ;;
    "Darwin-arm64") _platform="darwin-arm64" ;;
    *) err "Unsupported platform ${_os}-${_arch}. Please install asdf-vm manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}." ;;
    esac

    mkdir -p "$LOCAL_BIN"

    curl -sSL --fail "https://github.com/asdf-vm/asdf/releases/download/${_latest_version}/asdf-${_latest_version}-${_platform}.tar.gz" | tar xzf - -C "$LOCAL_BIN"

    _profile=""
    case ${SHELL:-""} in
    */zsh)
      _profile=$HOME/.zshrc
      ;;
    */bash)
      if [ "$(uname)" = "Darwin" ]; then
        _profile=$HOME/.bash_profile
      else
        _profile=$HOME/.bashrc
      fi
      ;;
    */sh)
      _profile=$HOME/.profile
      ;;
    *)
      err "Could not detect shell, manually add ${LOCAL_BIN_ESCAPED} and \${ASDF_DATA_DIR:-\$HOME/.asdf}/shims to your PATH and re-run this script."
      ;;
    esac

    touch "$_profile"

    echo >>"$_profile" && echo "export PATH=\"${LOCAL_BIN_ESCAPED}:\$PATH\"" >>"$_profile"
    echo >>"$_profile" && echo "export PATH=\"\${ASDF_DATA_DIR:-\$HOME/.asdf}/shims:\$PATH\"" >>"$_profile"

    export PATH="${LOCAL_BIN}:$PATH"
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

    say "asdf-vm has been installed."
  else
    err "cancelled asdf-vm installation. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi
}

main "$@" || exit 1
