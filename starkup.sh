#!/bin/sh

set -eu

SCRIPT_VERSION="0.2.3"

SCRIPT_URL="https://sh.starkup.sh"
REPO_URL="https://github.com/software-mansion/starkup"

ASDF_DEFAULT_VERSION="0.16.7"
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
if [ -z "${NO_COLOR:-}" ] && echo "${TERM:-}" | grep -q "^xterm"; then
  BOLD="\033[1m"
  RED="\033[31m"
  YELLOW="\033[33m"
  RESET="\033[0m"
fi

SCARB_UNINSTALL_INSTRUCTIONS="For uninstallation instructions, refer to https://docs.swmansion.com/scarb/download#uninstall"
# TODO(#2): Link snfoundry uninstall docs once they are available
GENERAL_UNINSTALL_INSTRUCTIONS="Try removing TOOL binaries from ${LOCAL_BIN}"

# Set of latest mutually compatible tool versions
SCARB_LATEST_COMPATIBLE_VERSION="2.10.1"
FOUNDRY_LATEST_COMPATIBLE_VERSION="0.39.0"
COVERAGE_LATEST_COMPATIBLE_VERSION="0.5.0"
PROFILER_LATEST_COMPATIBLE_VERSION="0.8.1"

usage() {
  cat <<EOF
The installer for Starknet tools. Installs the latest versions of Scarb, Starknet Foundry and Universal Sierra Compiler using asdf.

Usage: $0 [OPTIONS]

Options:
  -h, --help             Print help
  -V, --version          Print script version
  -y, --yes              Disable confirmation prompt
  --version-set <set>    Version set to install. Possible options: compatible (default), latest
EOF
}

main() {
  need_interaction=true
  version_set="compatible"

  # Transform long options to short ones
  for arg in "$@"; do
    shift
    case "$arg" in
    '--help') set -- "$@" '-h' ;;
    '--version') set -- "$@" '-V' ;;
    '--yes') set -- "$@" '-y' ;;
    '--version-set') set -- "$@" '-s' ;;
    *) set -- "$@" "$arg" ;;
    esac
  done

  while getopts ":hVys:" opt; do
    case $opt in
    h)
      usage
      exit 0
      ;;
    V)
      say "starkup $SCRIPT_VERSION"
      exit 0
      ;;
    y)
      need_interaction=false
      ;;
    s)
      if [ "$OPTARG" = "compatible" ] || [ "$OPTARG" = "latest" ]; then
        version_set="$OPTARG"
      else
        err "invalid version set: '$OPTARG'. Valid options: 'compatible', 'latest'."
      fi
      ;;
    \?)
      err "invalid option: -$OPTARG. For more information, try '--help'."
      ;;
    :)
      err "option -$OPTARG requires an argument. For more information, try '--help'."
      ;;
    esac
  done

  # Check for any unprocessed arguments
  shift $((OPTIND - 1))
  if [ $# -gt 0 ]; then
    err "unexpected argument: $1. For more information, try '--help'."
  fi

  info "Installing $version_set version set..."

  assert_dependencies "$need_interaction"

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
    if [ "$version_set" = "latest" ]; then
      latest_version=$(get_latest_version "$tool")
      install_version "$tool" "$latest_version"
      set_global_version "$tool" "$latest_version"
    else
      compatible_version=$(get_compatible_version "$tool")
      install_version "$tool" "$compatible_version"
      set_global_version "$tool" "$compatible_version"
    fi
  done

  if [ "$version_set" = "latest" ]; then
    warn "Installed version set 'latest' might contain incompatible versions. If you encounter issues, consider using '--version-set compatible' instead. For more information, refer to ${REPO_URL}."
  fi

  shell_config=""
  completion_message=""

  case ${SHELL:-""} in
  */zsh)
    shell_config="$HOME/.zshrc"
    completion_message="Run 'source ${shell_config}'"
    ;;
  */bash)
    if [ "$(uname)" = "Darwin" ]; then
      shell_config="$HOME/.bash_profile"
    else
      shell_config="$HOME/.bashrc"
    fi
    completion_message="Run 'source ${shell_config}'"
    ;;
  */sh)
    shell_config="$HOME/.profile"
    completion_message="Run '. ${shell_config}'"
    ;;
  *)
    warn "Could not detect shell. Make sure ${LOCAL_BIN_ESCAPED} and ${ASDF_SHIMS_ESCAPED} are added to your PATH."
    completion_message="Source your shell configuration file"
    ;;
  esac

  add_alias "${shell_config}"

  info "Installation complete. ${completion_message} or start a new terminal session to use the installed tools."
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
  _latest_version=$(get_latest_version "$_tool")
  install_version "$_tool" "$_latest_version"
}

install_compatible_version() {
  _tool="$1"
  _compatible_version=$(get_compatible_version "$_tool")
  install_version "$_tool" "$_compatible_version"
}

install_version() {
  _tool="$1"
  _installed_version="$2"
  if check_version_installed "$_tool" "$_installed_version"; then
    info "$_tool $_installed_version is already installed"
  else
    ensure asdf install "$_tool" "$_installed_version"
  fi
}

check_version_installed() {
  _tool="$1"
  _version="$2"
  asdf list "$_tool" | grep -q "^[^0-9]*${_version}$"
}

get_latest_version() {
  _tool="$1"
  asdf latest "$_tool"
}

get_compatible_version() {
  _tool="$1"
  case "$_tool" in
  "scarb")
    echo "$SCARB_LATEST_COMPATIBLE_VERSION"
    ;;
  "starknet-foundry")
    echo "$FOUNDRY_LATEST_COMPATIBLE_VERSION"
    ;;
  "cairo-coverage")
    echo "$COVERAGE_LATEST_COMPATIBLE_VERSION"
    ;;
  "cairo-profiler")
    echo "$PROFILER_LATEST_COMPATIBLE_VERSION"
    ;;
  *)
    err "unknown tool: $_tool"
    ;;
  esac
}

set_global_latest_version() {
  _tool="$1"
  _latest_version=$(get_latest_version "$_tool")
  set_global_version "$_tool" "$_latest_version"
}

set_global_compatible_version() {
  _tool="$1"
  _compatible_version=$(get_compatible_version "$_tool")
  set_global_version "$_tool" "$_compatible_version"
}

set_global_version() {
  _tool="$1"
  _global_version="$2"

  if is_asdf_legacy; then
    ensure asdf global "$_tool" "$_global_version"
  else
    ensure asdf set --home "$_tool" "$_global_version"
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
  _latest_gh_version=$(get_latest_gh_version "$_repo") && [ -n "$_latest_gh_version" ] || {
    warn "Failed to fetch latest version for $_repo (possibly due to GitHub server rate limit or error). Using default version $_default_version." >&2
    _latest_gh_version="$_default_version"
  }

  echo "$_latest_gh_version"
}

install_universal_sierra_compiler() {
  _usc_version=""
  _usc_latest_version=""
  if check_cmd universal-sierra-compiler; then
    _usc_version=$(universal-sierra-compiler --version 2>/dev/null | awk '{print $2}')
    _usc_latest_version=$(get_latest_gh_version "software-mansion/universal-sierra-compiler")
  fi

  if [ -z "$_usc_version" ] || [ "$_usc_version" != "$_usc_latest_version" ]; then
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
    code --install-extension StarkWare.cairo1 --force
  fi
}

get_asdf_version() {
  asdf --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$'
}

# asdf versions < 0.16.0 are legacy
is_asdf_legacy() {
  _asdf_version=$(get_asdf_version)
  version_less_than "$_asdf_version" "0.16.0"
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

    _asdf_latest_version=$(get_latest_gh_version_or_default "asdf-vm/asdf" "$ASDF_DEFAULT_VERSION")

    download_asdf "$_asdf_latest_version"

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
  _asdf_current_version=$(get_asdf_version)
  if is_asdf_legacy; then
    warn "asdf-vm $_asdf_current_version is legacy and cannot be updated. Please update manually. For migration instructions, refer to ${ASDF_MIGRATION_DOCS}."
    return
  fi

  _asdf_latest_version=$(get_latest_gh_version_or_default "asdf-vm/asdf" "$ASDF_DEFAULT_VERSION")
  if ! version_less_than "$_asdf_current_version" "$_asdf_latest_version"; then
    info "asdf-vm is up to date."
    return
  fi

  if [ "$(command -v asdf)" != "${LOCAL_BIN}/asdf" ]; then
    warn "asdf-vm $_asdf_current_version was not installed by starkup. Please update manually. See details: ${ASDF_INSTALL_DOCS}."
    return
  fi

  download_asdf "$_asdf_latest_version"
  info "asdf-vm updated to $_asdf_latest_version."
}

download_asdf() {
  _asdf_version="$1"

  info "Downloading asdf-vm $_asdf_version..."

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

  curl -sSL --fail "https://github.com/asdf-vm/asdf/releases/download/v${_asdf_version}/asdf-v${_asdf_version}-${_platform}.tar.gz" | tar xzf - -C "$LOCAL_BIN"
}

version_less_than() {
  _version1="$1"
  _version2="$2"
  printf '%s\n%s' "$_version1" "$_version2" | sort -V | head -n1 | grep -xqvF "$_version2"
}

main "$@" || exit 1
