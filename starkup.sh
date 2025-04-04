#!/bin/sh

set -eu

SCRIPT_VERSION="0.2.3"

SCRIPT_URL="https://sh.starkup.sh"

ASDF_DEFAULT_VERSION="0.16.5"
ASDF_INSTALL_DOCS="https://asdf-vm.com/guide/getting-started.html"
ASDF_MIGRATION_DOCS="https://asdf-vm.com/guide/upgrading-to-v0-16.html"
ASDF_SHIMS="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
ASDF_SHIMS_ESCAPED="\${ASDF_DATA_DIR:-\$HOME/.asdf}/shims"

LOCAL_BIN="${HOME}/.local/bin"
LOCAL_BIN_ESCAPED="\${HOME}/.local/bin"

BOLD=""
RED=""
YELLOW=""
RESET=""

# Check whether colors are supported and should be enabled
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v tput >/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  BOLD="\033[1m"
  RED="\033[31m"
  YELLOW="\033[33m"
  RESET="\033[0m"
fi

SCARB_UNINSTALL_INSTRUCTIONS="For uninstallation instructions, refer to https://docs.swmansion.com/scarb/download#uninstall"
# TODO(#2): Link snfoundry uninstall docs once they are available
GENERAL_UNINSTALL_INSTRUCTIONS="Try removing TOOL binaries from ${LOCAL_BIN}"


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

  tools_list='scarb starknet-foundry cairo-coverage cairo-profiler'
  assert_not_installed_outside_asdf "$tools_list"

  install_universal_sierra_compiler
  install_vscode_plugin

  # todo(scarb#1989): after profiler and coverage have shorthand plugin names,
  # move plugin installation into the for loop below
  install_latest_asdf_plugin "scarb"
  install_latest_asdf_plugin "starknet-foundry"
  install_latest_asdf_plugin "cairo-coverage" "https://github.com/software-mansion/asdf-cairo-coverage.git"
  install_latest_asdf_plugin "cairo-profiler" "https://github.com/software-mansion/asdf-cairo-profiler.git"

  for tool in $tools_list; do
    install_latest_version "$tool"
    set_global_latest_version "$tool"
  done

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
    warn "Could not detect shell. Make sure ${LOCAL_BIN_ESCAPED} and ${ASDF_SHIMS_ESCAPED} are added to your PATH."
    _completion_message="Source your shell configuration file"
    ;;
  esac

  add_alias "${_shell_config}"

  info "Installation complete. ${_completion_message} or start a new terminal session to use the installed tools."
}

add_alias() {
  _shell_config="$1"
  _alias_def="alias starkup=\"curl --proto '=https' --tlsv1.2 -sSf ${SCRIPT_URL} | sh -s --\""

  if [ -z "$_shell_config" ]; then
    warn "Could not detect shell. To simplify access to the installer, add the following to your shell configuration file:\nalias starkup=\"curl --proto '=https' --tlsv1.2 -sSf ${SCRIPT_URL} | sh -s --\""
    return
  fi

  if ! grep -q "^alias starkup" "${_shell_config}"; then
    cat <<EOF >>"${_shell_config}"
# Alias for running starkup installer
$_alias_def
EOF
    info "'starkup' alias added to ${_shell_config}. You can use 'starkup' to directly access the installer next time."
  fi
}

assert_dependencies() {
  _need_interaction="$1"
  need_cmd curl
  need_cmd git
  if ! check_cmd asdf; then
    install_asdf "$_need_interaction"
  else
    update_asdf
  fi
}

assert_not_installed_outside_asdf() {
  _tools_list="$*"
  _installed_tools=""

  for _tool in $_tools_list; do
    _uninst_instructions=""
    _tool_cmds=""

    case "$_tool" in
    "scarb")
      _uninst_instructions="$SCARB_UNINSTALL_INSTRUCTIONS"
      _tool_cmds="scarb"
      ;;
    "starknet-foundry")
      _uninst_instructions=$(echo "$GENERAL_UNINSTALL_INSTRUCTIONS" | sed "s/TOOL/snforge and sncast/g")
      _tool_cmds="snforge sncast"
      ;;
    "cairo-coverage")
      _uninst_instructions=$(echo "$GENERAL_UNINSTALL_INSTRUCTIONS" | sed "s/TOOL/cairo-coverage/g")
      _tool_cmds="cairo-coverage"
      ;;
    "cairo-profiler")
      _uninst_instructions=$(echo "$GENERAL_UNINSTALL_INSTRUCTIONS" | sed "s/TOOL/cairo-profiler/g")
      _tool_cmds="cairo-profiler"
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
  _url=${2:-""}
  if check_asdf_plugin_installed "$_plugin"; then
    ensure asdf plugin update "$_plugin"
  else
    ensure asdf plugin add "$_plugin" "$_url"
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
    info "$_tool $_latest_version is already installed"
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
  curl -sS --fail "https://api.github.com/repos/${_repo}/releases/latest" | awk -F'"' '/"tag_name"/ {print $4}' | sed 's/^v//'
}

get_latest_gh_version_or_default() {
  _repo="$1"
  _default_version="$2"

  # shellcheck disable=SC2015
  _latest_version=$(get_latest_gh_version "$_repo") && [ -n "$_latest_version" ] || {
    warn "Failed to fetch latest version for $_repo (possibly due to GitHub server rate limit or error). Using default version $_default_version." >&2
    _latest_version="$_default_version"
  }

  echo "$_latest_version"
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

info() {
  say "${BOLD}info:${RESET} $1"
}

warn() {
  say "${BOLD}${YELLOW}warn:${RESET} ${YELLOW}$1${RESET}"
}

err() {
  say "${BOLD}${RED}error:${RESET} ${RED}$1${RESET}" >&2
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

install_vscode_plugin() {
  if check_cmd code; then
    code --install-extension StarkWare.cairo1
  fi
}

get_asdf_version() {
  asdf --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$'
}

# asdf versions < 0.16.0 are legacy
is_asdf_legacy() {
  _version=$(get_asdf_version)
  version_less_than "$_version" "0.16.0"
}

install_asdf() {
  _need_interaction="$1"
  _answer=""
  if "$_need_interaction"; then
    info "asdf-vm is required but not found.\nFor seamless updates, install it using a package manager (e.g., Homebrew, AUR helpers). See details: ${ASDF_INSTALL_DOCS}.\nAlternatively, the script can install asdf-vm directly, but manual updates might be needed later.\nProceed with direct installation? (y/N):"
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

    _latest_version=$(get_latest_gh_version_or_default "asdf-vm/asdf" "$ASDF_DEFAULT_VERSION")

    download_asdf "$_latest_version"

    export PATH="${LOCAL_BIN}:$PATH"
    export PATH="${ASDF_SHIMS}:$PATH"

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
    esac

    if [ -n "$_profile" ]; then
      touch "$_profile"
      echo >>"$_profile" && echo "export PATH=\"${LOCAL_BIN_ESCAPED}:\$PATH\"" >>"$_profile"
      echo >>"$_profile" && echo "export PATH=\"${ASDF_SHIMS_ESCAPED}:\$PATH\"" >>"$_profile"
    fi
    info "asdf-vm has been installed."
  else
    err "cancelled asdf-vm installation. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
  fi
}

update_asdf() {
  _current_version=$(get_asdf_version)
  if is_asdf_legacy; then
    warn "asdf-vm $_current_version is legacy and cannot be updated. Please update manually. For migration instructions, refer to ${ASDF_MIGRATION_DOCS}."
    return
  fi

  _latest_version=$(get_latest_gh_version_or_default "asdf-vm/asdf" "$ASDF_DEFAULT_VERSION")
  if ! version_less_than "$_current_version" "$_latest_version"; then
    info "asdf-vm is up to date."
    return
  fi

  if [ "$(command -v asdf)" != "${LOCAL_BIN}/asdf" ]; then
    warn "asdf-vm $_current_version was not installed by starkup and cannot be updated. Please update manually. See details: ${ASDF_INSTALL_DOCS}."
    return
  fi

  download_asdf "$_latest_version"
  info "asdf-vm updated to $_latest_version."
}

download_asdf() {
  _version="$1"

  info "Downloading asdf-vm $_version..."

  _os="$(uname -s)"
  _arch="$(uname -m)"
  case "${_os}-${_arch}" in
  "Linux-x86_64") _platform="linux-amd64" ;;
  "Linux-aarch64") _platform="linux-arm64" ;;
  "Linux-i386" | "Linux-i686") _platform="linux-386" ;;
  "Darwin-x86_64") _platform="darwin-amd64" ;;
  "Darwin-arm64") _platform="darwin-arm64" ;;
  *) err "Unsupported platform ${_os}-${_arch}." ;;
  esac

  mkdir -p "$LOCAL_BIN"

  curl -sSL --fail "https://github.com/asdf-vm/asdf/releases/download/v${_version}/asdf-v${_version}-${_platform}.tar.gz" | tar xzf - -C "$LOCAL_BIN"
}

version_less_than() {
  _version1="$1"
  _version2="$2"
  printf '%s\n%s' "$_version1" "$_version2" | sort -V | head -n1 | grep -xqvF "$_version2"
}

main "$@" || exit 1
